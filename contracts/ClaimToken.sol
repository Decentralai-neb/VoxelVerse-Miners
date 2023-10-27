// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClaimToken is ERC20, ERC20Burnable, Ownable {
    address public allowedMinterContract;
    uint256 public constant maxSupply = 20000 ether;
    constructor()
        ERC20("ClaimToken", "CLAIM")
    {
        _mint(msg.sender, 200 * 10 ** decimals());
    }

    function setMinterContract(address _minterContract) external onlyOwner {
        allowedMinterContract = _minterContract;
    }
    
    modifier onlyContract() {
        require(msg.sender == allowedMinterContract, "Only the allowed contract can call this function");
        _;
    }

    function mint(address user) external onlyContract {
        uint256 amount = 1;
        require(totalSupply() + amount <= maxSupply, "Total supply exceeds the maximum limit");
        _mint(user, amount);
    }

}