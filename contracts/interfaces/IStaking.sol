// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IStaking { function stakes(address) external view returns (uint256 amount, uint256 unlockAt); }
