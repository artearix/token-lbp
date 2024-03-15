// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);
}