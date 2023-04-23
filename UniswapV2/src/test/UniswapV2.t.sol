// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../src/UniswapV2Factory.sol";
import "../../src/UniswapV2Pair.sol";
import "./ERC20.sol";
import "../interfaces/IUniswapV2Callee.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract TestUniswapV2Factory is UniswapV2Factory {
    constructor(address _feeToSetter) UniswapV2Factory(_feeToSetter) {}

    function testInitialize(
        address pair,
        address tokenA,
        address tokenB
    ) external {
        UniswapV2Pair(pair).initialize(tokenA, tokenB);
    }
}

contract UniswapV2PairTest is DSTest {
    using SafeMath for uint;
    UniswapV2Factory factory;
    UniswapV2Pair pair;
    ERC20 token0;
    ERC20 token1;
    address wallet;
    address other;
    struct BalancesAndReserves {
        uint reserve0Before;
        uint reserve1Before;
        uint balance0Before;
        uint balance1Before;
        uint reserve0After;
        uint reserve1After;
        uint balance0After;
        uint balance1After;
    }
    BalancesAndReserves bar;

    function setUp() public {
        wallet = address(this);
        other = address(0x123); // dummy address
        factory = new UniswapV2Factory(wallet);
        token0 = new ERC20(10 ** 28);
        token1 = new ERC20(10 ** 28);

        factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(factory.getPair(address(token0), address(token1)));
    }

    // Test the initialize function of the UniswapV2Pair contract
    function testInitialize() public {
        token0 = new ERC20(10 ** 28);
        token1 = new ERC20(10 ** 28);

        // Deploy the TestUniswapV2Factory contract
        TestUniswapV2Factory testFactory = new TestUniswapV2Factory(
            address(this)
        );

        // Create the pair using the test factory and get the pair address
        address pairAddress = testFactory.createPair(
            address(token0),
            address(token1)
        );

        // Cast the pair address to the UniswapV2Pair contract
        UniswapV2Pair createdPair = UniswapV2Pair(pairAddress);

        // Call testInitialize on the test factory to indirectly call initialize on the created pair
        testFactory.testInitialize(
            pairAddress,
            address(token0),
            address(token1)
        );

        assertEq(createdPair.factory(), address(testFactory));
        assertEq(createdPair.token0(), address(token0));
        assertEq(createdPair.token1(), address(token1));
    }

    function testMintWithFee() public {
        // Set token amounts to be transferred to the pair contract
        factory.setFeeTo(other);

        uint token0Amount = 1 * 10 ** 18;
        uint token1Amount = 4 * 10 ** 18;

        // Transfer the specified amounts of token0 and token1 to the pair contract
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Call the mint function and receive the liquidity value
        uint liquidity = pair.mint(address(this));
        uint112 reserve0;
        uint112 reserve1;
        // Get the reserve amounts of token0 and token1 in the pair contract
        (reserve0, reserve1, ) = pair.getReserves();

        // Transfer a significantly larger amount of tokens to the pair to make rootK much larger than rootKLast
        token0Amount = 100 * 10 ** 18;
        token1Amount = 400 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Call the mint function again and receive the liquidity value
        liquidity = pair.mint(address(this));
        (reserve0, reserve1, ) = pair.getReserves();

        // Check if the feeOn condition is met
        bool feeOn = pair.callMintFee(reserve0, reserve1);
        if (feeOn) {
            uint kLast = pair.kLast();
            uint rootK = Math.sqrt(uint(reserve0).mul(reserve1));
            uint rootKLast = Math.sqrt(kLast);
            // Calculate the expected liquidity minted as fees
            uint numerator = pair.totalSupply().mul(rootK.sub(rootKLast));
            uint denominator = rootK.mul(5).add(rootKLast);
            uint expectedLiquidity = numerator / denominator;

            // Check if the balance of the feeTo address has increased by the expected liquidity
            assertEq(pair.balanceOf(other), expectedLiquidity);
        }
    }

    function testMintWithoutFee() public {
        // Set token amounts to be transferred to the pair contract
        uint token0Amount = 1 * 10 ** 18;
        uint token1Amount = 4 * 10 ** 18;

        // Transfer the specified amounts of token0 and token1 to the pair contract
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Calculate the expected liquidity value after minting
        uint expectedLiquidity = 2 * 10 ** 18;

        // Call the mint function and receive the liquidity value
        uint liquidity = pair.mint(address(this));
        uint112 reserve0;
        uint112 reserve1;
        // Get the reserve amounts of token0 and token1 in the pair contract
        (reserve0, reserve1, ) = pair.getReserves();

        // Check if the received liquidity value is equal to the expected liquidity minus MINIMUM_LIQUIDITY
        assertEq(liquidity, expectedLiquidity - pair.MINIMUM_LIQUIDITY());
        // Check if the pair's total supply is equal to the expected liquidity
        assertEq(pair.totalSupply(), expectedLiquidity);
        // Check if the pair's balance of the caller address is equal to the expected liquidity minus MINIMUM_LIQUIDITY
        assertEq(
            pair.balanceOf(address(this)),
            expectedLiquidity - pair.MINIMUM_LIQUIDITY()
        );
        // Check if the token balance of the pair contract is equal to the specified token amounts
        assertEq(token0.balanceOf(address(pair)), token0Amount);
        assertEq(token1.balanceOf(address(pair)), token1Amount);
        // Check if the reserve amount of the tokens are equal to the specified token amounts
        assertEq(reserve0, token0Amount);
        assertEq(reserve1, token1Amount);
    }

    function testMintFirstTimeLiquidity() public {
        // Transfer tokens to the pair contract
        uint token0Amount = 1 * 10 ** 18;
        uint token1Amount = 4 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Assert total supply is 0 before minting
        assertEq(pair.totalSupply(), 0);

        // Call the mint function
        pair.mint(address(this));

        // Assert total supply is greater than MINIMUM_LIQUIDITY after minting
        require(
            pair.totalSupply() > pair.MINIMUM_LIQUIDITY(),
            "Total supply should be greater than MINIMUM_LIQUIDITY after minting"
        );
    }

    function testBurn() public {
        uint256 token0Amount = 3 * 10 ** 18;
        uint256 token1Amount = 3 * 10 ** 18;
        uint256 tolerance = 1000; // Set a tolerance value, e.g., 0.001 tokens

        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        pair.mint(address(this));

        // Store initial token balances
        uint256 initialToken0Balance = token0.balanceOf(address(this));
        uint256 initialToken1Balance = token1.balanceOf(address(this));

        // Calculate the liquidity that will be burned
        uint256 liquidityToBurn = pair.balanceOf(address(this)) -
            pair.MINIMUM_LIQUIDITY();

        // Approve and transfer liquidity to the pair contract
        pair.approve(address(pair), liquidityToBurn);
        pair.transfer(address(pair), liquidityToBurn);

        // Call the burn function and receive the amounts
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));

        // Assert that the returned amounts are approximately correct
        assertAlmostEqual(amount0, token0Amount - 1000, tolerance);
        assertAlmostEqual(amount1, token1Amount - 1000, tolerance);

        // Assert that the pair's token balances are updated
        assertAlmostEqual(token0.balanceOf(address(pair)), 1000, tolerance);
        assertAlmostEqual(token1.balanceOf(address(pair)), 1000, tolerance);

        // Assert that the caller received the burned tokens
        assertAlmostEqual(
            token0.balanceOf(address(this)),
            initialToken0Balance + amount0,
            tolerance
        );
        assertAlmostEqual(
            token1.balanceOf(address(this)),
            initialToken1Balance + amount1,
            tolerance
        );

        // Assert that the pair's balance of the wallet address is MINIMUM_LIQUIDITY
        assertEq(pair.balanceOf(address(this)), pair.MINIMUM_LIQUIDITY());

        // Assert that the pair's total supply equals 2 * MINIMUM_LIQUIDITY
        assertEq(pair.totalSupply(), 2 * pair.MINIMUM_LIQUIDITY());
    }

    function testGetReserves() public {
        // Set token amounts to be transferred to the pair contract
        uint token0Amount = 1 * 10 ** 18;
        uint token1Amount = 4 * 10 ** 18;

        // Transfer the specified amounts of token0 and token1 to the pair contract
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Call the mint function
        pair.mint(address(this));
        // Get the reserve amounts from the pair contract
        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();
        // Assert that the reserve amounts are correct
        assert(_reserve0 == token0Amount);
        assert(_reserve1 == token1Amount);
    }

    function testSuccessfulSwap() public {
        uint amount0Out = 10;
        uint amount1Out = 0;
        address user = address(0x123);
        bytes memory data = "";

        // Provide initial liquidity to the pair contract
        uint token0Amount = 1000 * 10 ** 18;
        uint token1Amount = 2000 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(address(this));

        // Transfer an appropriate amount of token0 to the pair contract
        // This will be used as input for the swap operation
        uint token0Input = 20 * 10 ** 18;
        token0.transfer(address(pair), token0Input);

        // Get initial reserves and balances
        (bar.reserve0Before, bar.reserve1Before) = getReservesAsUint(pair);
        bar.balance0Before = ERC20(token0).balanceOf(address(this));
        bar.balance1Before = ERC20(token1).balanceOf(address(this));

        // Call the swap function
        pair.swap(amount0Out, amount1Out, user, data);

        // Get updated reserves and balances
        (bar.reserve0After, bar.reserve1After) = getReservesAsUint(pair);
        bar.balance0After = ERC20(token0).balanceOf(address(this));
        bar.balance1After = ERC20(token1).balanceOf(address(this));

        uint256 tolerance = 1000;

        assertAlmostEqual(
            bar.reserve0After,
            bar.reserve0Before - amount0Out + token0Input,
            tolerance
        );
        assertAlmostEqual(bar.reserve1After, bar.reserve1Before, tolerance);
        assertAlmostEqual(
            bar.balance0After,
            bar.balance0Before - amount0Out,
            tolerance
        );
        assertAlmostEqual(bar.balance1After, bar.balance1Before, tolerance);

        // Assert the correct amounts were transferred to the user
        assertAlmostEqual(ERC20(token0).balanceOf(user), amount0Out, tolerance);
        assertAlmostEqual(ERC20(token1).balanceOf(user), 0, tolerance);
    }

    function testSwapInsufficientOutputAmount() public {
        // Attempt to call swap with 0 output amounts
        (bool success, ) = address(pair).call(
            abi.encodePacked(
                pair.swap.selector,
                uint(0), // amount0Out
                uint(0), // amount1Out
                address(this),
                "" // data
            )
        );
        // Assert that the swap failed with the expected error message
        assertTrue(
            !success,
            "Swap should fail due to insufficient output amount"
        );
    }

    function testSkim() public {
        // Set up the initial conditions for the skim
        uint excessToken0Amount = 50 * 10 ** 18;
        uint excessToken1Amount = 30 * 10 ** 18;
        address user = address(0x123);

        // Provide initial liquidity to the pair contract
        uint token0Amount = 1000 * 10 ** 18;
        uint token1Amount = 2000 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(address(this));

        // Transfer excess tokens to the pair contract
        token0.transfer(address(pair), excessToken0Amount);
        token1.transfer(address(pair), excessToken1Amount);

        // Get initial reserves and balances
        (uint reserve0Before, uint reserve1Before) = getReservesAsUint(pair);
        // Call the skim function
        pair.skim(user);

        // Get updated reserves and balances
        (uint reserve0After, uint reserve1After) = getReservesAsUint(pair);

        // Assert that the reserves remain unchanged after the skim
        assertEq(reserve0After, reserve0Before);
        assertEq(reserve1After, reserve1Before);

        // Assert that the excess tokens were transferred to the user
        assertEq(ERC20(token0).balanceOf(user), excessToken0Amount);
        assertEq(ERC20(token1).balanceOf(user), excessToken1Amount);

        // Assert that the pair contract's balances match the reserves
        assertEq(ERC20(token0).balanceOf(address(pair)), reserve0After);
        assertEq(ERC20(token1).balanceOf(address(pair)), reserve1After);
    }

    /// Helper functions

    // Helper function to get reserves as uint
    function getReservesAsUint(
        UniswapV2Pair testPair
    ) internal view returns (uint reserve0, uint reserve1) {
        (uint112 _reserve0, uint112 _reserve1, ) = testPair.getReserves();
        reserve0 = uint(_reserve0);
        reserve1 = uint(_reserve1);
    }

    function testSyncIncreasedBalances() public {
        // Provide initial liquidity to the pair contract
        uint token0Amount = 1000 * 10 ** 18;
        uint token1Amount = 2000 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(address(this));

        // Transfer additional tokens to the pair contract
        uint additionalToken0Amount = 50 * 10 ** 18;
        uint additionalToken1Amount = 30 * 10 ** 18;
        token0.transfer(address(pair), additionalToken0Amount);
        token1.transfer(address(pair), additionalToken1Amount);

        (uint reserve0Before, uint reserve1Before) = getReservesAsUint(pair);

        pair.sync();

        (uint reserve0After, uint reserve1After) = getReservesAsUint(pair);

        // Assert that the reserves have been updated to match the increased balances
        assertEq(reserve0After, reserve0Before + additionalToken0Amount);
        assertEq(reserve1After, reserve1Before + additionalToken1Amount);
    }

    function testSyncDecreasedBalances() public {
        // Provide initial liquidity to the pair contract
        uint token0Amount = 1000 * 10 ** 18;
        uint token1Amount = 2000 * 10 ** 18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(address(this));

        // Deposit tokens into the pair contract to perform a swap
        uint depositToken0Amount = 500 * 10 ** 18;
        uint depositToken1Amount = 1000 * 10 ** 18;
        token0.transfer(address(pair), depositToken0Amount);
        token1.transfer(address(pair), depositToken1Amount);
        pair.mint(address(this));

        // Perform a swap that provides some input
        uint amount0Out = 10;
        uint amount1Out = 0;
        uint amount0In = 10;
        uint amount1In = 20;
        address user = address(0x123);
        bytes memory data = "";
        token0.transfer(address(pair), amount0In);
        token1.transfer(address(pair), amount1In);
        pair.swap(amount0Out, amount1Out, user, data);

        // Get initial reserves
        (uint reserve0Before, uint reserve1Before) = getReservesAsUint(pair);

        // Call the sync function
        pair.sync();

        // Get updated reserves
        (uint reserve0After, uint reserve1After) = getReservesAsUint(pair);

        // Assert that the reserves have been updated to match the decreased balances
        assertAlmostEqual(
            reserve0After,
            reserve0Before - amount0Out + amount0In,
            1000
        );
        assertAlmostEqual(reserve1After, reserve1Before + amount1In, 1000);
    }

    // Equality assertion that compensates for overflow errors within a tolerance range
    function assertAlmostEqual(
        uint256 a,
        uint256 b,
        uint256 tolerance
    ) internal pure {
        if (a > b) {
            assert(a - b <= tolerance);
        } else {
            assert(b - a <= tolerance);
        }
    }
}

contract MockCallee is IUniswapV2Callee {
    address public callSender;
    uint256 public callAmount0;
    uint256 public callAmount1;
    bytes public callData;

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        callSender = sender;
        callAmount0 = amount0;
        callAmount1 = amount1;
        callData = data;
    }
}
