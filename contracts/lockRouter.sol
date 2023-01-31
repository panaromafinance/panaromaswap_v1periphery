// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.6;

import "./lockStorageV1Library.sol";
import "./TransferHelper.sol";

interface IPanaromaswapV1LockFactory {
    function getLockPair(address _lpToken, address _withdrawer) external returns (address);
    function lockLPToken(address _lpToken, uint256 _amount, uint256 _unlock_date, address _withdrawer) external returns (address);
    function addLocking(address _lpToken, uint256 _amount, uint256 _unlock_date, address _withdrawer) external;
}

contract lockRouter {

    address public panaromaswapFactory;
    address public panaromaswapLockFactory;

    constructor (address _panaromaswapFactory, address _panaromaswapLockFactory) public{
        panaromaswapFactory = _panaromaswapFactory;
        panaromaswapLockFactory = _panaromaswapLockFactory;
    }

    function _addLiq(address _lpToken, address _address, uint256 _amount, uint256 _unlock_date) internal virtual returns (address pair){
        if (IPanaromaswapV1LockFactory(panaromaswapLockFactory).getLockPair(_lpToken, _address) == address(0) || IPanaromaswapV1LockFactory(panaromaswapLockFactory).getLockPair(_address, _lpToken) == address(0)) {
            pair = IPanaromaswapV1LockFactory(panaromaswapLockFactory).lockLPToken(_lpToken, _amount, _unlock_date, _address);
        }else {
            IPanaromaswapV1LockFactory(panaromaswapLockFactory).addLocking(_lpToken, _amount, _unlock_date, msg.sender);
            pair = IPanaromaswapV1LockFactory(panaromaswapLockFactory).getLockPair(_lpToken, _address);
        }
    }

    function createLocking(address _lpToken, uint256 _amount, uint256 _unlock_date) external returns(address _pair) {
        _addLiq(_lpToken, msg.sender, _amount, _unlock_date);
        // _pair = lockStorageV1Library.pairFor(address(panaromaswapLockFactory), _lpToken, msg.sender);
        // _pair = IPanaromaswapV1LockFactory(panaromaswapLockFactory).getLockPair(_lpToken, msg.sender);
        // address _pair = lockStorageV1Library.pairFor(address(panaromaswapFactory), msg.sender, _lpToken);
        _pair = IPanaromaswapV1LockFactory(panaromaswapLockFactory).getLockPair(_lpToken, msg.sender);
        TransferHelper.safeTransferFrom(_lpToken, msg.sender, _pair, _amount);
        // IPanaromaswapV1LockeStorage(_pair).initialize(_lpToken, _amount, _unlock_date, _withdrawer);
    }
}