// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DeaiToken} from "contracts/DeaiToken.sol";

contract TokenTest is Test {
    function testMint() public {
        DeaiToken t = new DeaiToken("DeAI","DEAI",1e27);
        t.mint(address(this), 123);
        assertEq(t.balanceOf(address(this)), 1e27 + 123);
        assertEq(t.name(), "DeAI");
        assertEq(t.symbol(), "DEAI");
    }
}
