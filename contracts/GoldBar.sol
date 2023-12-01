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

contract VoxelVerseGoldBar is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {

    uint256 public constant goldbar = 6;

    IERC1155 public gold;
    IERC20 public prospect;
    // required materials to mint a goldbar
    mapping (uint256 => uint256) public requiredMaterials;

    // prospect required can be adjusted by owner
    uint256 public prospectRequired = 0.03 ether;

    constructor(IERC1155 _gold, IERC20 _prospect)
        ERC1155("https://ipfs.io/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/{id}.json")
    {
        gold = IERC1155(_gold);
        prospect = IERC20(_prospect);
        requiredMaterials[1] = 3; // 3 Gold Nuggets
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

    function setProspectPrice(uint256 newPrice) public onlyOwner {
        prospectRequired = newPrice;
    }

    function mint(uint256 amount)
        public
    {
        // Check that the user has the required materials to mint a new SKLMiner token
        require(gold.balanceOf(msg.sender, 4) >= requiredMaterials[1], "Insufficient gold nuggets");
        // Check that the user has enough PROSPECT tokens to mint a gold bar
        require(prospect.balanceOf(msg.sender) >= prospectRequired, "Insufficient PROSPECT tokens");
        // Transfer the required materials from the user to the contract
        gold.safeTransferFrom(msg.sender, address(this), 4, requiredMaterials[1], "");

        prospect.transferFrom(msg.sender, address(this), prospectRequired);


        _mint(msg.sender, 6, amount, "");
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

    function withdrawTokens() external onlyOwner {
        uint256 prospectBalance = prospect.balanceOf(address(this));
        require(prospectBalance > 0, "No PROSPECT tokens to withdraw");
        prospect.transfer(owner(), prospectBalance);
    }

    function withdrawGoldNuggets() external onlyOwner {
        uint256 goldBalance = gold.balanceOf(address(this), 4);
        require(goldBalance > 0, "No gold nuggets to withdraw");
        gold.safeTransferFrom(address(this), owner(), 4, goldBalance, "");
    }
}