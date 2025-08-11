// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeaiToken} from "contracts/DeaiToken.sol";
import {Staking} from "contracts/Staking.sol";
import {WorkerRegistry} from "contracts/WorkerRegistry.sol";
import {Marketplace} from "contracts/Marketplace.sol";
import {Treasury} from "contracts/Treasury.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk; try vm.envUint("DEPLOYER_KEY") returns (uint256 k) { pk = k; } catch { pk = 0; }
        if (pk != 0) vm.startBroadcast(pk); else vm.startBroadcast();

        DeaiToken token = new DeaiToken("DeAI","DEAI", 1e27);
        console2.log("Token:", address(token));

        Staking staking = new Staking(IERC20(address(token)), 100e18, 1 days);
        console2.log("Staking:", address(staking));

        WorkerRegistry reg = new WorkerRegistry();
        console2.log("WorkerRegistry:", address(reg));

        Treasury treasury = new Treasury();
        console2.log("Treasury:", address(treasury));

        Marketplace market = new Marketplace(
            IERC20(address(token)),
            address(staking),
            address(treasury),
            msg.sender
        );
        console2.log("Marketplace:", address(market));

        address client = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address worker = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        token.mint(client,  1_000e18);
        token.mint(worker,  1_000e18);

        vm.stopBroadcast();
    }
}
