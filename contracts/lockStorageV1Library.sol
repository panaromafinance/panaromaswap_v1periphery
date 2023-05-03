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

}
