// SPDX-License-Identifier: UNLICENSED

// This contract locks panaromaswap v1 liquidity tokens. Used to give investors peace of mind a token team has locked liquidity
// and that the tokens cannot be removed from panaromaswap until the specified unlock date has been reached.

pragma solidity 0.6.6;

import "./TransferHelper.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PanaromaswapV1LockeStorage.sol";

interface IPanaromaswapV1LockeStorage {
    function initialize(address _lpToken, uint256 _amount, uint256 _unlock_date, address _withdrawer) external;
}

contract PanaromaswapV1LockFactory is Ownable{
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  address[] public allLockPairs;
  mapping(address => mapping(address => address)) public getLockPair;

  event onDeposit(address lpToken, address user, uint256 amount, uint256 lockDate, uint256 unlockDate);

  address public panaromaswapFactory;

  constructor(address _panaromaswapFactory) public {
    panaromaswapFactory = _panaromaswapFactory;
  }

  function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address _withdrawer) external returns (address _pair) {
    require(_unlock_date < 10000000000, 'TIMESTAMP INVALID'); // prevents errors when timestamp entered in milliseconds
    require(_amount > 0, 'INSUFFICIENT');
    require(_lpToken != _withdrawer, 'PanaromaswapV1: IDENTICAL_ADDRESSES');
    (address token0, address token1) = _lpToken < _withdrawer ? (_lpToken, _withdrawer) : (_withdrawer, _lpToken);
    require(token0 != address(0), 'PanaromaswapV1: ZERO_ADDRESS');
    require(getLockPair[token0][token1] == address(0), 'PanaromaswapV1: PAIR_EXISTS');
    IPanaromaswapV1Pair lpair = IPanaromaswapV1Pair(address(_lpToken));
    address factoryPairAddress = IPanaromaFactory(panaromaswapFactory).getPair(lpair.token0(), lpair.token1());
    require(factoryPairAddress == address(_lpToken), 'NOT PANAV1');

    bytes memory bytecode = type(PanaromaswapV1LockeStorage).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_lpToken, _amount, _unlock_date, _withdrawer));
        assembly {
          _pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

    IPanaromaswapV1LockeStorage(_pair).initialize(_lpToken, _amount, _unlock_date, _withdrawer);
    getLockPair[_withdrawer][_lpToken] = _pair;
    getLockPair[_lpToken][_withdrawer] = _pair;
    allLockPairs.push(_pair);
    // TransferHelper.safeTransferFrom(_lpToken, address(msg.sender), _pair, _amount);
    emit onDeposit(_lpToken, msg.sender, _amount, now, _unlock_date);
  }

  function addLocking(address _lpToken, uint256 _amount, uint256 _unlock_date, address _withdrawer) public {
    require(_lpToken != address(0), 'PanaromaswapV1: Address0 Invalid!');
    require(_unlock_date < 10000000000, 'TIMESTAMP INVALID'); // prevents errors when timestamp entered in milliseconds
    require(_amount > 0, 'INSUFFICIENT');
    require(_lpToken != _withdrawer, 'PanaromaswapV1: IDENTICAL_ADDRESSES');
    (address token0, ) = _lpToken < _withdrawer ? (_lpToken, _withdrawer) : (_withdrawer, _lpToken);
    require(token0 != address(0), 'PanaromaswapV1: ZERO_ADDRESS');
    // require(getLockPair[token0][token1] == address(0), 'PanaromaswapV1: PAIR_EXISTS');
    IPanaromaswapV1Pair lpair = IPanaromaswapV1Pair(address(_lpToken));
    address factoryPairAddress = IPanaromaFactory(panaromaswapFactory).getPair(lpair.token0(), lpair.token1());
    require(factoryPairAddress == address(_lpToken), 'NOT PANAV1');

    address _pair = getLockPair[_lpToken][_withdrawer];
    IPanaromaswapV1LockeStorage(_pair).initialize(_lpToken, _amount, _unlock_date, _withdrawer);
  }

}
