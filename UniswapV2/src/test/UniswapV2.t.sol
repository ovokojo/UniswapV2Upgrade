// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../src/UniswapV2Factory.sol";
import "../../src/UniswapV2Pair.sol";
import "./ERC20.sol";

contract UniswapV2PairTest is DSTest {
    UniswapV2Factory factory;
    UniswapV2Pair pair;
    ERC20 token0;
    ERC20 token1;
    address wallet;
    address other;

    function setUp() public {
        wallet = address(this);
        other = address(0x123); // dummy address

        factory = new UniswapV2Factory(wallet);
        token0 = new ERC20(10 ** 28);
        token1 = new ERC20(10 ** 28);

        factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(factory.getPair(address(token0), address(token1)));
    }

    function testExample() public {
        assertTrue(true);
    }

    function testMint() public {
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

    function TestBurn() public {
        uint256 token0Amount = 3 * 10 ** 18;
        uint256 token1Amount = 3 * 10 ** 18;
        uint256 tolerance = 1000; // Set a tolerance value, e.g., 0.001 tokens

        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        // Mint liquidity
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

contract UniswapV2FactoryTest is DSTest {
    function testExample() public {
        assertTrue(true);
    }
}
