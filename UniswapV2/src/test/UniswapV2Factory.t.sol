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

contract UniswapV2FactoryTest is DSTest {
    UniswapV2Factory factory;
    UniswapV2Pair pair;
    ERC20 token0;
    ERC20 token1;
    address wallet;
    address other;

    function setUp() public {
        wallet = address(this);
        other = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // dummy address
        factory = new UniswapV2Factory(wallet);
        token0 = new ERC20(10 ** 28);
        token1 = new ERC20(10 ** 28);
    }

    function testallPairsLength() public {
        assertEq(factory.allPairsLength(), 0);
    }

    function testCreatePair() public {
        factory.createPair(address(token0), address(token1));
        assertEq(factory.allPairsLength(), 1);
    }

    function testFeeTo() public {
        assertEq(factory.feeTo(), address(0));
        factory.setFeeTo(other);
        assertEq(factory.feeTo(), other);
    }

    function testFeeToSetter() public {
        assertEq(factory.feeToSetter(), wallet);
        factory.setFeeToSetter(other);
        assertEq(factory.feeToSetter(), other);
    }
}
