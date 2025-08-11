// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeaiToken} from "contracts/DeaiToken.sol";
import {Staking} from "contracts/Staking.sol";
import {WorkerRegistry} from "contracts/WorkerRegistry.sol";
import {Marketplace} from "contracts/Marketplace.sol";

contract MarketplaceFlowTest is Test {
    DeaiToken token;
    Staking staking;
    WorkerRegistry reg;
    Marketplace market;

    address client     = address(0xC1);
    address worker1    = address(0xA1);
    address treasury   = address(0x1001);
    address arbitrator = address(0xAB);

    function oneAddress(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }
    function oneUint(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    function setUp() public {
        token   = new DeaiToken("DeAI","DEAI",1e27);
        staking = new Staking(IERC20(address(token)), 100e18, 1 days);
        reg     = new WorkerRegistry();
        market  = new Marketplace(IERC20(address(token)), address(staking), treasury, arbitrator);

        token.mint(client,  1_000e18);
        token.mint(worker1, 1_000e18);

        vm.prank(worker1);
        IERC20(address(token)).approve(address(staking), type(uint256).max);
        vm.prank(worker1);
        staking.stake(100e18);
    }

    function testFlow_PostSubmitSettle() public {
        vm.prank(client);
        IERC20(address(token)).approve(address(market), type(uint256).max);

        vm.warp(100);
        vm.prank(client);
        uint256 jobId = market.postJob(100e18, 1, uint64(block.timestamp + 1 days), "ipfs://spec");
        assertEq(jobId, 1);

        vm.prank(worker1);
        market.submit(jobId, "ipfs://result", bytes32(uint256(0x1234)));

        address[] memory winners = oneAddress(worker1);
        uint256[] memory payouts = oneUint(97e18);

        vm.prank(client);
        market.settleAgreed(jobId, bytes32(uint256(0x1234)), winners, payouts);

        // Worker wallet: 1000 - 100 staked + 97 payout = 997
        assertEq(token.balanceOf(worker1), 997e18);

        // Stake remains 100
        (uint256 staked, ) = staking.stakes(worker1);
        assertEq(staked, 100e18);

        // Treasury fee = 3
        assertEq(token.balanceOf(treasury), 3e18);
    }
}
