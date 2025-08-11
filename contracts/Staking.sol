// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ReentrancyGuard, Ownable {
    IERC20 public immutable token;
    uint256 public minStake;
    uint256 public cooldown;

    struct StakeInfo { uint256 amount; uint256 unlockAt; }
    mapping(address => StakeInfo) public stakeInfo;

    event Staked(address indexed staker, uint256 amount);
    event UnstakeBegun(address indexed staker, uint256 amount, uint256 unlockAt);
    event Unstaked(address indexed staker, uint256 amount);
    event Slashed(address indexed staker, uint256 amount, bytes32 reason);

    constructor(IERC20 token_, uint256 minStake_, uint256 cooldownSec_)
        Ownable(msg.sender)
    {
        token = token_;
        minStake = minStake_;
        cooldown = cooldownSec_;
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        StakeInfo storage s = stakeInfo[msg.sender];
        token.transferFrom(msg.sender, address(this), amount);
        s.amount += amount;
        require(s.amount >= minStake, "below minStake");
        emit Staked(msg.sender, amount);
    }

    function beginUnstake(uint256 amount) external nonReentrant {
        StakeInfo storage s = stakeInfo[msg.sender];
        require(s.amount >= amount, "insufficient");
        s.amount -= amount;
        uint256 unlockAt = block.timestamp + cooldown;
        s.unlockAt = unlockAt;
        emit UnstakeBegun(msg.sender, amount, unlockAt);
    }

    function finishUnstake() external nonReentrant {
        StakeInfo storage s = stakeInfo[msg.sender];
        require(s.unlockAt != 0 && block.timestamp >= s.unlockAt, "cooldown");
        uint256 amt = s.amount; s.amount = 0; s.unlockAt = 0;
        token.transfer(msg.sender, amt);
        emit Unstaked(msg.sender, amt);
    }

    function slash(address staker, uint256 amount, bytes32 reason) external onlyOwner {
        StakeInfo storage s = stakeInfo[staker];
        require(s.amount >= amount, "exceeds");
        s.amount -= amount;
        token.transfer(owner(), amount);
        emit Slashed(staker, amount, reason);
    }

    function stakes(address who) external view returns (uint256 amount, uint256 unlockAt) {
        StakeInfo memory s = stakeInfo[who];
        return (s.amount, s.unlockAt);
    }
}
