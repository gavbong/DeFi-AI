
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract DeaiToken is ERC20, Ownable {
    constructor() ERC20("DeAI","DEAI") { _mint(msg.sender, 1e27); }
    function mint(address to, uint256 amount) external onlyOwner { _mint(to, amount); }
}
