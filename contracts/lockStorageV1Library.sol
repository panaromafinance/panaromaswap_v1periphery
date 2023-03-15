// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.6;

import './libraries/SafeMath.sol';
// import './PanaromaswapV1LockeStorage.sol';

// library containing some math for dealing with the liquidity shares of a pair, e.g. computing their exact value
// in terms of the underlying tokens
library lockStorageV1Library {
    using SafeMath for uint;

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PanaromaswapV1Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PanaromaswapV1Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address token0, address token1) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(token0, token1);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'59678869e9ef16e3c8fb5e405499ae5c98535c043c0ad6ef3992db2402ec081b' // init code hash
            ))));
    }

}
