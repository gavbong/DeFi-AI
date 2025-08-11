// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DeaiToken} from "contracts/DeaiToken.sol";
import {Staking} from "contracts/Staking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingTest is Test {
    DeaiToken token;
    Staking staking;
    address alice = address(0xA11CE);

    function setUp() public {
        token = new DeaiToken("DeAI","DEAI",1e27);
        staking = new Staking(IERC20(address(token)), 100e18, 1 days);
        token.mint(alice, 200e18);
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
    }

    function testStakeAndBeginUnstake() public {
        vm.prank(alice);
        staking.stake(100e18);
        (uint256 amt, uint256 unlockAt) = staking.stakes(alice);
        assertEq(amt, 100e18);
        assertEq(unlockAt, 0);

        vm.warp(block.timestamp + 1);
        vm.prank(alice);
        staking.beginUnstake(50e18);

        (amt, unlockAt) = staking.stakes(alice);
        assertEq(amt, 50e18);
        assertGt(unlockAt, 0);
    }
}
