// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/Base64.sol";
import "./interfaces/IStone.sol";
import "./interfaces/IWood.sol";

import "hardhat/console.sol";

contract VoxelVerseWindmill is ERC721, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // event handling
    event TokensMinted(address indexed owner, uint256 amount);

    // Individual counters for each windmill
    Counters.Counter private _windmillTokenIds;

    // Windmill supply control
    uint256 public windmillSupply = 14000;

    // Mapping to track windmills minted by address
    mapping(address => uint256) public windmillsMintedByAddress;

    // Pricing
    uint256 public premCap = 450 ether; 
    uint256 public highCap = 90 ether;
    uint256 public medCap = 60 ether;
    uint256 public lowCap = 40 ether;

    // Free Claims
    uint256 public claimPremCap = 4 ether; 
    uint256 public claimHighCap = 3 ether;
    uint256 public claimMedCap = 2 ether;
    uint256 public claimLowCap = 1 ether;

    // Increase cap pricing
    uint256 public windCapIncreaseRate;   

    // used for calculating emission rate per block
    uint256 public windmillCap; // Windmill cap set on mint of miner

    struct TokenInfo {
        IERC20 paytoken;
        string name;
    }

    TokenInfo[] public AllowedCrypto;
    mapping(uint256 => uint) public rates;
    address public wood; // wood contract
    address public stone; // stone contract

    mapping (uint256 => uint256) public requiredMaterials;

    // Windmill Data
    struct Windmill {
        uint256 tokenId; // Token Id of windmill
        uint256 currentPowerUsed; // The current amount of power used
        uint256 windmillCap; // The current generating capacity of a windmill
        string imageURI; // The windmill image
    }
    mapping(uint256 => Windmill) public windmills; // Access Windmill Struct
    mapping(uint256 => address) private windmillOwners; // Windmill owner by address
    mapping(address => uint256) public windmillHolders;
    

    constructor() ERC721("VoxelVerseWindmill", "vWIND") {
        requiredMaterials[1] = 8;
        requiredMaterials[2] = 12;
        requiredMaterials[3] = 16;
        requiredMaterials[4] = 24;
        requiredMaterials[5] = 32;
        requiredMaterials[6] = 80;
        requiredMaterials[7] = 106;
        string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";

        // Initialize windmills and their imageURIs
        for (uint256 tokenId = 1; tokenId <= windmillSupply; tokenId++) {
            string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(tokenId), ".png"));
            
            windmills[tokenId].imageURI = imageURI;
        }
    }

    function checkIfUserHasWindmill() external view returns (Windmill memory) {
        // Get the tokenId of the user's character NFT
        uint256 userNftTokenId = windmillHolders[msg.sender];
        // If the user has a tokenId in the map, return their character.
        if (userNftTokenId > 0) {
            return windmills[userNftTokenId];
        }
        // Else, return an empty character.
        else {
            Windmill memory emptyStruct;
            return emptyStruct;
        }
    }

     function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        Windmill memory windmillToken = windmills[_tokenId];

        string memory strPower = Strings.toString(windmillToken.currentPowerUsed);
        string memory strCap = Strings.toString(windmillToken.windmillCap);
        string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
        string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(_tokenId), ".png"));

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                ' VoxelVerse Windmill #: ',
                Strings.toString(_tokenId),
                '", "description": "Power your Crypto Miners", "image": "',
                imageURI, // Use the dynamically generated imageURI
                '", "attributes": [ { "trait_type": "Power Consumption", "value": ',strPower,'} , { "trait_type": "Power Capacity", "value": ',strCap,'}]}'
            )
        );

        string memory itemUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return itemUri;
    }



    function mintWindmill(uint256 _cap, uint256 _pid, string memory _imageURI) public {
        require(windmillsMintedByAddress[msg.sender] == 0, "Caller already owns a Windmill");
        require(_cap == 500 || _cap == 150 || _cap == 100 || _cap == 50, "Invalid _cap value");
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;

        uint256 requiredPrice;
        uint256 _requiredMaterial1;
        uint256 _requiredMaterial2;

        if (_cap == 500) {
            requiredPrice = premCap;
            _requiredMaterial1 = requiredMaterials[6];
            _requiredMaterial2 = requiredMaterials[7];
        } else if (_cap == 150) {
            requiredPrice = highCap;
            _requiredMaterial1 = requiredMaterials[4];
            _requiredMaterial2 = requiredMaterials[5];
        } else if (_cap == 100) {
            requiredPrice = medCap;
            _requiredMaterial1 = requiredMaterials[3];
            _requiredMaterial2 = requiredMaterials[4];
        } else if (_cap == 50) {
            requiredPrice = lowCap;
            _requiredMaterial1 = requiredMaterials[1];
            _requiredMaterial2 = requiredMaterials[2];
        }

        require(_windmillTokenIds.current() <= windmillSupply, "Windmill supply exceeded");
        require(paytoken.balanceOf(msg.sender) >= requiredPrice, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(this), requiredPrice);
        address user = msg.sender; // required parameters in the wood and stone contracts
        IWood(wood).burnWood(user, _requiredMaterial1);
        IStone(stone).burnStone(user, _requiredMaterial2);
        // Create a new windmill with the specified _cap
        uint256 generatorToken = _windmillTokenIds.current().add(16200);

        windmills[generatorToken] = Windmill({
            tokenId: generatorToken,
            currentPowerUsed: 0,
            windmillCap: _cap,
            imageURI:_imageURI
        });
        // Mint the Windmill token with the correct token ID
        safeMintWindmill(msg.sender);

        // Increment the count of windmills minted by the sender's address
        windmillsMintedByAddress[msg.sender]++;
    }

    function claimWindmill(uint256 _cap, uint256 _pid, string memory _imageURI) public {
        require(windmillsMintedByAddress[msg.sender] == 0, "Caller already owns a Windmill");
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;

        uint256 requiredPrice;
        uint256 _requiredMaterial1;
        uint256 _requiredMaterial2;

        if (_cap == 500) {
            requiredPrice = claimPremCap;
            _requiredMaterial1 = requiredMaterials[6];
            _requiredMaterial2 = requiredMaterials[7];
        } else if (_cap == 150) {
            requiredPrice = claimHighCap;
            _requiredMaterial1 = requiredMaterials[4];
            _requiredMaterial2 = requiredMaterials[5];
        } else if (_cap == 100) {
            requiredPrice = claimMedCap;
            _requiredMaterial1 = requiredMaterials[3];
            _requiredMaterial2 = requiredMaterials[4];
        } else if (_cap == 50) {
            requiredPrice = claimLowCap;
            _requiredMaterial1 = requiredMaterials[1];
            _requiredMaterial2 = requiredMaterials[2];
        }

        require(_windmillTokenIds.current() <= windmillSupply, "Windmill supply exceeded");
        require(paytoken.balanceOf(msg.sender) >= requiredPrice, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(this), requiredPrice);
        address user = msg.sender; // the address is a required parameter of the stone burn function
        IWood(wood).burnWood(user, _requiredMaterial1);
        IStone(stone).burnStone(user, _requiredMaterial2);

        // Create a new windmill with the specified _cap
        uint256 generatorToken = _windmillTokenIds.current().add(14000);

        windmills[generatorToken] = Windmill({
            tokenId: generatorToken,
            currentPowerUsed: 0,
            windmillCap: _cap,
            imageURI: _imageURI
        });
        // Mint the Windmill token with the correct token ID
        safeMintWindmill(msg.sender);

        // Increment the count of windmills minted by the sender's address
        windmillsMintedByAddress[msg.sender]++;
    }

    function boostWindmillCap(uint256 tokenId, uint256 amount, uint256 _pid) public {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        // Ensure the caller is the owner of the miner
        address owner = ownerOf(tokenId);
        require(tokenId >= 14000 && tokenId < 28000, "invalid token Id");
        require(msg.sender == owner, "Not the owner of the token");

        // Deduct the boost cost from the sender's balance
        require(paytoken.balanceOf(msg.sender) >= windCapIncreaseRate, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(this), windCapIncreaseRate.mul(amount));
        // Get the windmill details
        Windmill storage windmill = windmills[tokenId];
        // Update the windmills capacity
       windmill.windmillCap = windmill.windmillCap.add(amount);  
    }

     // Function to retrieve a Windmill struct by tokenId
    function getWindmill(uint256 tokenId) public view returns (Windmill memory) {
        return windmills[tokenId];
    }


    // Safemint

    function safeMintWindmill(address to) internal {
        uint256 tokenId = _windmillTokenIds.current().add(14000);
        _windmillTokenIds.increment();
        windmillHolders[msg.sender] = tokenId;
        _safeMint(to, tokenId);
    }

    // onlyOwner functions

    function airdropWindmillCap(uint256 tokenId, uint256 amount) public onlyOwner{
        require(tokenId >= 16200 && tokenId < 32200, "invalid token Id");
        // Get the windmill details
        Windmill storage windmill = windmills[tokenId];
        // Update the windmills capacity
       windmill.windmillCap = windmill.windmillCap.add(amount);  
    }

    function addCurrency(
        IERC20 _paytoken, string memory _name
    ) public onlyOwner {
        AllowedCrypto.push(
            TokenInfo({
                paytoken: _paytoken, name: _name
            })
        );
    }

    // Update the token address and name for a specific pid
    function updateCurrency(uint256 _pid, IERC20 _newPaytoken, string memory _newName) public onlyOwner {
        require(_pid < AllowedCrypto.length, "Invalid pid");
        
        TokenInfo storage tokenInfo = AllowedCrypto[_pid];
        tokenInfo.paytoken = _newPaytoken;
        tokenInfo.name = _newName;
    }

    // Set rate for PROSPECT token used to boost windmill
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    // Set Cap increase rates for the windmill
    function setWindmillCapRate(uint256 _rate) public onlyOwner { 
        windCapIncreaseRate = _rate;
    }

    // Set purchase price for windmills according to initial capacity
    function setLowCap(uint256 _price) public onlyOwner {
        lowCap = _price;
    }

    function setMedCap(uint256 _price) public onlyOwner {
        medCap = _price;
    }

    function setHighCap(uint256 _price) public onlyOwner {
        highCap = _price;
    }

    function setPremCap(uint256 _price) public onlyOwner {
        premCap = _price;
    }

    // Set purchase price for windmills according to initial capacity
    function setClaimLowCap(uint256 _price) public onlyOwner {
        claimLowCap = _price;
    }

    function setClaimMedCap(uint256 _price) public onlyOwner {
        claimMedCap = _price;
    }

    function setClaimHighCap(uint256 _price) public onlyOwner {
        claimHighCap = _price;
    }

    function setClaimPremCap(uint256 _price) public onlyOwner {
        claimPremCap = _price;
    }

    // Withdraw ERC20 tokens
    function withdraw(uint256 _pid) public payable onlyOwner() {
            TokenInfo storage tokens = AllowedCrypto[_pid];
            IERC20 paytoken;
            paytoken = tokens.paytoken;
            paytoken.transfer(msg.sender, paytoken.balanceOf(address(this)));
    }

    // Withdraw Ethereum tokens
    function withdraw() public onlyOwner {
        uint amount = address(this).balance;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success,"Failed to withdraw");
   }

}