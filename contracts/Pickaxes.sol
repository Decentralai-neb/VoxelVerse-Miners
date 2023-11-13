// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/Base64.sol";
import "./interfaces/IProspectPowerBank.sol";
import "./interfaces/IDistributionPool.sol";
import "hardhat/console.sol";


contract Pickaxes is ERC721, Ownable {
    using Counters for Counters.Counter;

    // Event handling
    event TokensMinted(address indexed owner, uint256 amount);
    event MinerStarted(string minerType, address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 tokenId);

    // Pickaxe counter
    Counters.Counter private _pickaxeTokenIds;

    // Prospect Power Bank Contract
    address public pb;
    // Distribution Pool
    address public dp;

    // Pickaxe supply control
    uint256 public pickaxeSupply = 50000;

    // Pickaxe boost variables
    uint256 public constant pwr1 = 5;
    uint256 public constant pwr2 = 4;
    uint256 public constant pwr3 = 3;
    uint256 public constant pwr4 = 2;
    uint256 public constant pwr5 = 1;

    uint256 public unCommon = 99;
    uint256 public rare = 499;
    uint256 public epic = 1499;
    uint256 public legendary = 2999;

    uint256 public minimumDeposit = 1 ether;
    uint256 public lvl1Threshold = 100 ether;
    uint256 public lvl2Threshold = 500 ether;
    uint256 public lvl3Threshold = 1500 ether;
    uint256 public lvl4Threshold = 3000 ether;


    // Pickaxe Data
    struct Pickaxe {
        string name;
        string pickaxeRarity; // the pickaxe rarity
        uint256 pickaxePower; // the pickaxe power
        string imageURI; // the pickaxe image
    }

    mapping(uint256 => Pickaxe) public pickaxes; // Access pickaxe struct
    mapping(address => uint) private pickaxeHolders; // Pickaxe owners by address
    mapping (address => uint) public pickaxeMints; // Tracking of pickaxes minted per user , basically does the same thing as pickaxeHolders but used to regulate mint limit
    
    

    constructor() ERC721("Pickaxes", "pAXE") {
    }

    function checkIfUserHasPickaxe() public view returns (Pickaxe memory) {
        // Get the tokenId of the user's character NFT
        uint256 userNftTokenId = pickaxeHolders[msg.sender];
        // If the user has a tokenId in the map, return their character.
        if (userNftTokenId > 0) {
            return pickaxes[userNftTokenId];
        }
        // Else, return an empty character.
        else {
            Pickaxe memory emptyStruct;
            return emptyStruct;
        }
    }

     function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        Pickaxe memory pickaxeToken = pickaxes[_tokenId];

        string memory pickPWR = Strings.toString(pickaxeToken.pickaxePower);
        string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
        string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(_tokenId), ".png"));

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                pickaxeToken.name,
                ' -- Pickaxe #: ',
                Strings.toString(_tokenId),
                '", "description": "Boost your Pickaxe power to rank up!", "image": "',
                imageURI,
                '", "attributes": [{ "trait_type": "Pickaxe Rarity", "value": ',pickaxeToken.pickaxeRarity,'} , { "trait_type": "Pickaxe Power", "value": ',pickPWR,'}]}'
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // Mint a pickaxe
    function mintPickaxe() public {
            require(pickaxeMints[msg.sender] == 0, "Caller already owns a Pickaxe");
            uint256 pickaxeToken = _pickaxeTokenIds.current() + 1;

            string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
           
            pickaxes[pickaxeToken] = Pickaxe({
                name: "Pickaxe",  
                pickaxeRarity: "Common",
                pickaxePower: 1, // Replace this with the appropriate power
                imageURI: string(abi.encodePacked(baseImageURI, Strings.toString(pickaxeToken), ".png"))
                });
                safeMintPickaxe(msg.sender);

             pickaxeMints[msg.sender]++;
        
    }
    // Boost a pickaxes hashrate
    function depositBoostPickaxePower(uint256 tokenId, uint256 depositAmount) public {
        require(tokenId >= 1 && tokenId < 30000, "Invalid token Id");
        require(msg.sender == ownerOf(tokenId), "Not the owner of the token");
        require(depositAmount >= minimumDeposit, "Increase deposit amount");

        address user = msg.sender;
        IProspectPowerBank(pb).depositProspect(user, depositAmount);

        Pickaxe storage pickaxe = pickaxes[tokenId];
        uint256 currentBalance = IProspectPowerBank(pb).getUserBalance(user);
        uint256 pwrValue = currentBalance + depositAmount;

        // Update pickaxe power based on boosted parameters
        if (pwrValue < lvl1Threshold) {
            pickaxe.pickaxePower += pwr1;
        } else if (pwrValue < lvl2Threshold) {
            pickaxe.pickaxePower += pwr2;
        } else if (pwrValue < lvl3Threshold) {
            pickaxe.pickaxePower += pwr3;
        } else {
            pickaxe.pickaxePower += pwr4;
        }

        // Update pickaxe rarity based on power
        if (pickaxe.pickaxePower < rare) {
            pickaxe.pickaxeRarity = "UnCommon";
        } else if (pickaxe.pickaxePower < epic) {
            pickaxe.pickaxeRarity = "Rare";
        } else if (pickaxe.pickaxePower < legendary) {
            pickaxe.pickaxeRarity = "Epic";
        } else {
            pickaxe.pickaxeRarity = "Legendary";
        }
    }


     function withdrawReducePickaxePower(uint256 tokenId, uint256 withdrawAmount) public {
        require(tokenId >= 1 && tokenId < 30000, "Invalid token Id");
        require(msg.sender == ownerOf(tokenId), "Not the owner of the token");
        require(withdrawAmount >= minimumDeposit, "Increase withdrawal amount");

        address user = msg.sender;
        IProspectPowerBank(pb).withdrawProspect(user, withdrawAmount);

        Pickaxe storage pickaxe = pickaxes[tokenId];
        uint256 currentBalance = IProspectPowerBank(pb).getUserBalance(user);
        uint256 pwrValue = currentBalance - withdrawAmount;

        // Update pickaxe power
        if (pwrValue < lvl1Threshold) {
            pickaxe.pickaxePower -= pwr1;
        } else if (pwrValue < lvl2Threshold) {
            pickaxe.pickaxePower -= pwr2;
        } else if (pwrValue < lvl3Threshold) {
            pickaxe.pickaxePower -= pwr3;
        } else {
            pickaxe.pickaxePower -= pwr4;
        }

        // Update pickaxe rarity
        if (pickaxe.pickaxePower > unCommon && pickaxe.pickaxePower < rare) {
            pickaxe.pickaxeRarity = "UnCommon";
        } else if (pickaxe.pickaxePower < epic) {
            pickaxe.pickaxeRarity = "Rare";
        } else if (pickaxe.pickaxePower < legendary) {
            pickaxe.pickaxeRarity = "Epic";
        } else {
            pickaxe.pickaxeRarity = "Legendary";
        }
        }

    // Safemint

    function safeMintPickaxe(address to) internal {
        uint256 tokenId = _pickaxeTokenIds.current() + 1;
        _pickaxeTokenIds.increment();
        pickaxeHolders[msg.sender] = tokenId;
        _safeMint(to, tokenId);
    }

    function getPickaxeRarity(uint256 tokenId) public view returns (string memory){
        // Get the pickaxe details
        Pickaxe storage pickaxe = pickaxes[tokenId];
        return pickaxe.pickaxeRarity;
    }

    function getPickaxeMints(address referrer) external view returns (uint){
        return pickaxeMints[referrer];
    }

    function claimRewards(uint256 tokenId, uint256 amount) external {
        require(_exists(tokenId), "Invalid tokenId");
        uint256 _pid = 0; // prospect token
        address user = msg.sender;
        require(pickaxeHolders[user] == tokenId, "Not the owner of the token");

        Pickaxe storage pickaxe = pickaxes[tokenId];

        // Calculate the multiplier to apply based off the Pickaxe Rarity
        uint256 multiplier;
        if (keccak256(abi.encodePacked(pickaxe.pickaxeRarity)) == keccak256(abi.encodePacked("Common"))) {
            multiplier = 1;
        } else if (keccak256(abi.encodePacked(pickaxe.pickaxeRarity)) == keccak256(abi.encodePacked("UnCommon"))) {
            multiplier = 2;
        } else if (keccak256(abi.encodePacked(pickaxe.pickaxeRarity)) == keccak256(abi.encodePacked("Rare"))) {
            multiplier = 3;
        } else if (keccak256(abi.encodePacked(pickaxe.pickaxeRarity)) == keccak256(abi.encodePacked("Epic"))) {
            multiplier = 4;
        } else if (keccak256(abi.encodePacked(pickaxe.pickaxeRarity)) == keccak256(abi.encodePacked("Legendary"))) {
            multiplier = 5;
        }

        amount = amount * multiplier;

        // Call the appropriate claim function in the DistributionPool contract based on minerType
        IDistributionPool(dp).claim(user, _pid, amount);

        // Emit an event or perform other actions as needed
        emit RewardClaimed(user, tokenId);
    }

}