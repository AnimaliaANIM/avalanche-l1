// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20/ERC20Claimable.sol";

contract AnimaliaPhylum is ERC20, Ownable, ERC20Claimable {
    constructor()
        ERC20("Animalia Phylum", "PHL")
        ERC20Claimable("Animalia Phylum")
        Ownable(_msgSender())
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
