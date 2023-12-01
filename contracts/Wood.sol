// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";


contract VoxelVerseWood is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {
    event Burned(address indexed player, uint256 amount);
    uint256 public constant wood = 1;

    // mapping to store allowed contracts
    mapping(address => bool) public allowedContracts;

    constructor()
        ERC1155("https://ipfs.io/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/{id}.json")
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(uint256 amount)
        public
        onlyOwner
    {
        _mint(msg.sender, 1, amount, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, "");
    }

    function contractMint(uint256 amount)
        external
    {
         require(allowedContracts[msg.sender], "Caller does not have permission to call this function");
        _mint(msg.sender, 1, amount, "");
    }

    function contractMintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        external
    {
         require(allowedContracts[msg.sender], "Caller does not have permission to call this function");
        _mintBatch(to, ids, amounts, "");
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function burnWood(address user, uint256 amount) external {
        require(balanceOf(user, 1) > 0, "You don't any wood to burn!");

        // Destroy the wood token
        _burn(user, 1, amount);

        // Emit a Burned event
        emit Burned(user, amount);
    }
}
