// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../src/UniswapV2Factory.sol";
import "../../src/UniswapV2Pair.sol";
import "../../src/UniswapV2Router02.sol";
import "./ERC20.sol";
import "./WETH.sol";
import "../interfaces/IUniswapV2Callee.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract UniswapV2RouterTest is DSTest {
    UniswapV2Router02 router;
    UniswapV2Factory factory;
    UniswapV2Pair pair;
    ERC20 token0;
    ERC20 token1;
    ERC20 token2;
    address weth;
    address wallet;
    address other;

    function setUp() public {
        wallet = address(this);
        other = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        factory = new UniswapV2Factory(wallet);
        token0 = new ERC20(10 ** 30);
        token1 = new ERC20(10 ** 30);
        token2 = new ERC20(10 ** 30);
        weth = address(new ERC20(10 ** 30));
        factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(factory.getPair(address(token0), address(token1)));
        router = new UniswapV2Router02(address(factory));
    }

    function testQuote() public {
        uint amountA;
        uint reserveA;
        uint reserveB;
        uint expectedAmountB;
        // Test case 1
        amountA = 2e18;
        reserveA = 10e18;
        reserveB = 20e18;
        expectedAmountB = 4e18;
        assertEq(router.quote(amountA, reserveA, reserveB), expectedAmountB);
        // Test case 2
        amountA = 5e18;
        reserveA = 15e18;
        reserveB = 30e18;
        expectedAmountB = 10e18;
        assertEq(router.quote(amountA, reserveA, reserveB), expectedAmountB);
    }

    function assertEqApprox(uint a, uint b, uint epsilon) internal pure {
        if (a > b) {
            assert(a - b <= epsilon);
        } else {
            assert(b - a <= epsilon);
        }
    }

    function testAddLiquidityNewPair() public {
        ERC20 tokenA = new ERC20(10 ** 30);
        ERC20 tokenB = new ERC20(10 ** 30);

        uint256 amountADesired = 1e12;
        uint256 amountBDesired = 2e12;
        uint256 amountAMin = 1;
        uint256 amountBMin = 1;

        // Check that the pair doesn't exist yet
        assertTrue(
            factory.getPair(address(tokenA), address(tokenB)) == address(0)
        );

        // Approve the router to spend tokens on behalf of the test contract
        tokenA.approve(address(router), amountADesired);
        tokenB.approve(address(router), amountBDesired);

        (uint256 amountA, uint256 amountB, ) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this)
        );

        // Check that the pair now exists in the factory
        assertTrue(
            factory.getPair(address(tokenA), address(tokenB)) != address(0)
        );

        // Check that the returned amounts and liquidity are correct
        assertEq(amountA, amountADesired);
        assertEq(amountB, amountBDesired);
    }

    function testAddLiquidity() public {
        uint amountA = 1e18;
        uint amountB = 2e18;
        uint minLiquidity = 1;

        token0.transfer(other, amountA);
        token1.transfer(other, amountB);

        token0.approve(address(router), amountA);
        token1.approve(address(router), amountB);

        (uint amount0, uint amount1, uint liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            amountA,
            amountB,
            minLiquidity,
            minLiquidity,
            address(this)
        );
        assertEq(amount0, amountA);
        assertEq(amount1, amountB);
        assertEq(pair.balanceOf(address(this)), liquidity);
        // Approves the router contract to remove the liquidity tokens
        pair.approve(address(router), liquidity);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();

        uint liquidity = 1e18;
        uint minAmountA = 1;
        uint minAmountB = 1;

        // Add checks for balance and allowance before transferFrom
        uint balance = pair.balanceOf(address(this));
        uint allowance = pair.allowance(address(this), address(router));
        require(balance >= liquidity, "Insufficient balance");
        require(allowance >= liquidity, "Insufficient allowance");

        // Store the initial token balances
        uint initialBalanceA = token0.balanceOf(address(this));
        uint initialBalanceB = token1.balanceOf(address(this));

        (uint amountA, uint amountB) = router.removeLiquidity(
            address(token0),
            address(token1),
            liquidity,
            minAmountA,
            minAmountB,
            address(this)
        );

        // Check the difference in token balances against the amounts returned after removing liquidity
        assertEq(token0.balanceOf(address(this)) - initialBalanceA, amountA);
        assertEq(token1.balanceOf(address(this)) - initialBalanceB, amountB);
    }

    function testSuccessfulSwapExactTokensForTokens() public {
        uint256 amountIn = 1e12;
        uint256 amountOutMin = 1;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        address to = address(this);

        testAddLiquidity();

        // Approve the router to spend the input token on behalf of the test contract
        token0.approve(address(router), amountIn);

        // Store the initial token balances
        uint256 initialBalance0 = token0.balanceOf(address(this));
        uint256 initialBalance1 = token1.balanceOf(address(this));

        // Perform the token swap
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to
        );

        // Check if the input token balance has decreased by the specified amountIn
        assertEq(initialBalance0 - token0.balanceOf(address(this)), amountIn);

        // Check if the output token balance has increased by the expected amount
        assertEq(
            token1.balanceOf(address(this)) - initialBalance1,
            amounts[amounts.length - 1]
        );
    }

    function testFailedSwapExactTokensForTokens() public {
        uint256 amountIn = 1e12;
        uint256 amountOutMin = 1e30; // Set an unreasonably high minimum output amount
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        address to = address(this);

        // Add some liquidity to the pair
        testAddLiquidity();

        // Approve the router to spend the input token on behalf of the test contract
        token0.approve(address(router), amountIn);

        // Expect the test to fail due to the high minimum output amount
        (bool isFailed, ) = address(router).call(
            abi.encodeWithSelector(
                router.swapExactTokensForTokens.selector,
                amountIn,
                amountOutMin,
                path,
                to
            )
        );

        // Check if the swap failed as expected
        assert(isFailed);
    }

    function testSwapTokensForExactTokensSuccess() public {
        uint256 amountOut = 1e12;
        uint256 amountInMax = 1e18;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        address to = address(this);

        // Add some liquidity to the pair
        testAddLiquidity();

        // Approve the router to spend the input token on behalf of the test contract
        token0.approve(address(router), amountInMax);

        // Store the initial token1 balance
        uint256 initialToken1Balance = token1.balanceOf(to);

        // Call the swap function
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to
        );

        // Check if the swap was successful
        uint256 receivedToken1 = token1.balanceOf(to) - initialToken1Balance;
        assertTrue(amounts[0] <= amountInMax);
        assertEq(receivedToken1, amountOut);
    }

    function testSwapTokensForExactTokensFail() public {
        uint256 amountOut = 1e12;
        uint256 amountInMax = 1e10; // Set an unreasonably low maximum input amount
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        address to = address(this);

        // Add some liquidity to the pair
        testAddLiquidity();

        // Approve the router to spend the input token on behalf of the test contract
        token0.approve(address(router), amountInMax);

        // Call the swap function using a low-level call and capture the success and return data
        (bool success, ) = address(router).call(
            abi.encodeWithSelector(
                router.swapTokensForExactTokens.selector,
                amountOut,
                amountInMax,
                path,
                to
            )
        );

        // Check if the swap failed as expected
        assertTrue(!success);
    }

    function testSwapExactTokensForTokensOutputAmountTooLow() public {
        testAddLiquidity();

        uint256 amountIn = 1e12;
        uint256 amountOutMin = 1e18;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        address to = address(this);

        // Approve the router to spend tokens on behalf of the test contract
        token0.approve(address(router), amountIn);

        // Try to perform the swap
        (bool success, ) = address(router).call(
            abi.encodeWithSelector(
                router.swapExactTokensForTokens.selector,
                amountIn,
                amountOutMin,
                path,
                to
            )
        );

        // Check that the swap failed
        assertTrue(!success);
    }

    function testCalculateLiquidityReservesZero() public {
        (uint256 amountA, uint256 amountB) = router._calculateLiquidity(
            address(token0),
            address(token1),
            1e12,
            2e12,
            1,
            1
        );

        assertEq(amountA, 1e12);
        assertEq(amountB, 2e12);
    }

    function testCalculateLiquidityOptimalAmounts() public {
        testAddLiquidity();

        (uint256 amountA, uint256 amountB) = router._calculateLiquidity(
            address(token0),
            address(token1),
            1e12,
            2e12,
            1,
            1
        );

        assertTrue(amountA >= 1 && amountA <= 1e12);
        assertTrue(amountB >= 1 && amountB <= 2e12);
    }

    function testCalculateLiquidityInsufficientAmounts() public {
        testAddLiquidity();

        // Set the minimum amounts higher than the calculated optimal amounts
        bool success;
        (success, ) = address(router).call(
            abi.encodePacked(
                router._calculateLiquidity.selector,
                abi.encode(
                    address(token0),
                    address(token1),
                    1e12,
                    2e12,
                    2e12,
                    4e12
                )
            )
        );

        assertTrue(!success);
    }

    function testCalculateLiquidityAmountBOptimalGreater() public {
        testAddLiquidity();

        uint256 reserveA;
        uint256 reserveB;
        (reserveA, reserveB) = UniswapV2Library.getReserves(
            address(factory),
            address(token0),
            address(token1)
        );

        uint256 amountADesired = reserveA;
        uint256 amountBDesired = reserveB / 10;
        uint256 amountAMin = 1;
        uint256 amountBMin = 1;

        (uint256 amountA, uint256 amountB) = router._calculateLiquidity(
            address(token0),
            address(token1),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        assertTrue(amountA >= amountAMin && amountA <= amountADesired);
        assertTrue(amountB >= amountBMin && amountB <= amountBDesired);
    }
}
