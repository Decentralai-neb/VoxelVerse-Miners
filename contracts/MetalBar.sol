// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";


contract VoxelVerseMetalBar is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {
    event Burned(address indexed player, uint256 amount);
    uint256 public constant metalbar = 5;

    IERC1155 public iron;
    IERC20 public prospect;
    // required materials to mint a metalbar
    mapping (uint256 => uint256) public requiredMaterials;

    // prospect required can be adjusted by owner
    uint256 public prospectRequired = 0.015 ether;


    constructor(IERC1155 _iron, IERC20 _prospect)
        ERC1155("https://ipfs.io/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/{id}.json")
    {
        iron = IERC1155(_iron);
        prospect = IERC20(_prospect);
        requiredMaterials[1] = 3; // 3 Iron Nuggets
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setProspectRequired(uint256 newPrice) public onlyOwner {
        prospectRequired = newPrice;
    }

    function mint(uint256 amount)
        public
    {
         // Check that the user has the required materials to mint a new SKLMiner token
        require(iron.balanceOf(msg.sender, 3) >= requiredMaterials[1], "Insufficient Ore");
        // Check that the user has enough PROSPECT tokens to mint a gold bar
        require(prospect.balanceOf(msg.sender) >= prospectRequired, "Insufficient PROSPECT tokens");
       // Transfer the required materials from the user to the contract
        iron.safeTransferFrom(msg.sender, address(this), 3, requiredMaterials[1], "");

        prospect.transferFrom(msg.sender, address(this), prospectRequired);

        _mint(msg.sender, 5, amount, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, "");
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function onERC1155Received(
        address /* operator */,
        address /* from */ ,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function burnMetalBar(address user, uint256 amount) external {
        require(balanceOf(user, 5) > 0, "You don't any metal bars to burn!");

        // Destroy the metalbar token
        _burn(user, 5, amount);

        // Emit a Burned event
        emit Burned(user, amount);
    }


    function withdrawTokens() external onlyOwner {
        uint256 prospectBalance = prospect.balanceOf(address(this));
        require(prospectBalance > 0, "No PROSPECT tokens to withdraw");
        prospect.transfer(owner(), prospectBalance);
    }

    function withdrawiron() external onlyOwner {
        uint256 ironBalance = iron.balanceOf(address(this), 3);
        require(ironBalance > 0, "No ore to withdraw");
        iron.safeTransferFrom(address(this), owner(), 3, ironBalance, "");
    }
}