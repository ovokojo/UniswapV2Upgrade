// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "./interfaces/IUniswapV2Factory.sol";
import "../src/UniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";

contract UniswapV2Router02 {
    IUniswapV2Factory factory;

    constructor(address factoryAddress) {
        factory = IUniswapV2Factory(factoryAddress);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (factory.getPair(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pairAddress = UniswapV2Library.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);
        liquidity = IUniswapV2Pair(pairAddress).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = IUniswapV2Pair(pair).burn(to);
        if (amountA < amountAMin) revert("Insufficient A amount");
        if (amountA < amountBMin) revert("Insufficient B amount");
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(
            address(factory),
            amountIn,
            path
        );
        if (amounts[amounts.length - 1] < amountOutMin)
            revert("Output Amount Too Low");
        _safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(
            address(factory),
            amountOut,
            path
        );
        if (amounts[amounts.length - 1] > amountInMax)
            revert("Input Amount To High");
        _safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to_
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(
                    address(factory),
                    output,
                    path[i + 2]
                )
                : to_;
            IUniswapV2Pair(
                UniswapV2Library.pairFor(address(factory), input, output)
            ).swap(amount0Out, amount1Out, to, "");
        }
    }

    // **** INTERNAL FUNCTIONS ****

    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) public view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            address(factory),
            tokenA,
            tokenB
        );
        uint256 amountAOptimal;
        uint256 amountBOptimal;

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            amountBOptimal = UniswapV2Library.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal <= amountBMin)
                    revert("Insufficient amountB");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                amountAOptimal = UniswapV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal <= amountAMin)
                    revert("Insufficient amountB");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert("Transfer Failed");
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }
}
