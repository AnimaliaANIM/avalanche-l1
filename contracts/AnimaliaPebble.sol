// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract AnimaliaPebble is ERC20, Ownable, ERC20Permit {
    constructor()
        ERC20("Animalia Pebble", "ANIM PEB")
        ERC20Permit("Animalia Pebble")
        Ownable(_msgSender())
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
