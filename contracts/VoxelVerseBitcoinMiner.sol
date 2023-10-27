// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/Base64.sol";
import "./interfaces/IDistributionPool.sol";
import "./interfaces/IWindmill.sol";
import "./interfaces/IClaim.sol";
import "./interfaces/IStone.sol";
import "./interfaces/IWood.sol";

import "hardhat/console.sol";




contract VoxelVerseBitcoinMiner is ERC721, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // event handling
    event TokensMinted(address indexed owner, uint256 amount);
    event MinerStarted(string minerType, address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 tokenId);

    mapping (address => address) public referrals;
    mapping (address => uint) public claimTokensRewarded;
    mapping (address => uint) public minerMints;

    bool public btcPaused;

    // Individual counters for each miner
    Counters.Counter private _btcMinerTokenIds;

    // Miner supply control
    uint256 public bitcoinMinerSupply = 2000;

    // Pricing 
    uint256 public btcMinerPrice;
    uint256 public discountedPrice;
    uint256 public burnAmount;

    // Hashrate pricing
    uint256 public btcBoostRate;

    // used for calculating emission rate per block
    uint256 public truBhsh; 
    uint256 public dailyBlocks;
    uint256 initialHashrate = 5; // the initial hashrate of a miner once minted, default is 2.
    uint256 public constant hsh = 1; // bitcoin hash equivalent to 1TH used when hashrate is increased
    uint256 public constant minerPower = 1; // Used for miner power calculations

    struct TokenInfo {
        IERC20 paytoken;
        string name;
    }

    TokenInfo[] public AllowedCrypto;
    mapping(uint256 => uint) public rates;
    address public dp; // distribution pool
    address public wm; // windmill contract
    address public cm; // claim token contract

    // Emission rates, can be modified by owner or controller
    uint256 public btcReward;

    // Miner Data
    struct Miner {
        string token; // Token being mined by miner
        uint256 tokenId; // Token Id of miner
        string name; // Name of miner set by owner
        uint256 hashrate; // Miner hashrate
        string hashMeasured; // Hashrate measured in GH or TH
        uint256 powerConsumption; // Miner power consumption
        uint256 rewardPerBlock; // The miners earning per block
        uint lastUpdateBlock; // The last time a reward was claimed or when the miner began staking
        uint256 accumulated; // Unclaimed accumulated rewards left over before hashboost
        uint256 dailyEstimate; // pending rewards for a miner
        string imageURI; // Image of the miner
    }

    mapping(uint256 => Miner) public miners; // Access miner struct
    mapping(uint256 => uint256) public mintedCount; // Track minted tokens count per type
    mapping(address => uint256) public minerHolders; // Miner holders token Ids

    // Token mining global statistics
    struct BitcoinStats {
        uint256 minersHashing; // number of miners hashing
        uint256 totalHashrate; // the total hashrate of all Bitcoin miners
        uint256[] minerTokenIds; // Used for updating global emission rate data across all miners
        uint256 totalPowerConsumption;
        uint256 totalRewardsPaid;
    }
    BitcoinStats public bitcoin;

    constructor() ERC721("VoxelVerseBitcoinMiner", "VMBTC") {
        // Set the template URI for all miners
    string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";

    // Initialize miners and their imageURIs
    for (uint256 tokenId = 1; tokenId <= bitcoinMinerSupply; tokenId++) {
        string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(tokenId), ".png"));
        
        miners[tokenId].imageURI = imageURI;
    }
    }

    function checkIfUserHasMiner() public view returns (Miner memory) {
        // Get the tokenId of the user's character NFT
        uint256 userNftTokenId = minerHolders[msg.sender];
        // If the user has a tokenId in the map, return their character.
        if (userNftTokenId > 0) {
            return miners[userNftTokenId];
        }
        // Else, return an empty character.
        else {
            Miner memory emptyStruct;
            return emptyStruct;
        }
    }

     function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        Miner memory minerToken = miners[_tokenId];

        string memory strHashrate = Strings.toString(minerToken.hashrate);
        string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
        string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(_tokenId), ".png"));

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                minerToken.name,
                ' -- VoxelVerse Bitcoin Miner #: ',
                Strings.toString(_tokenId),
                '", "description": "Mine more blocks with your Crypto Miner", "image": "',
                imageURI, // Use the dynamically generated imageURI
                '", "attributes": [ { "trait_type": "Hashrate", "value": ',strHashrate,'}]}'
            )
        );

        string memory itemUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return itemUri;
    }



    modifier whenBtcNotPaused() {
        require(!btcPaused, "Bitcoin miner minting is paused");
        _;
    }

    function mintWithReferral(uint256 _pid, address referrer, string memory _imageURI) public {
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill();

        // Check if the user has a valid windmill based on the returned struct.
        require(userWindmill.tokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Now you can use 'userWindmill.tokenId' to retrieve information about the user's windmill.
        IWindmill.Windmill memory windmill = IWindmill(wm).getWindmill(userWindmill.tokenId);

        // Check if referrer address is valid
      if (referrer != address(0)) {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(minerMints[referrer] > 0, "Referrer has not minted a miner");
        
      }

        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 amount = 1;
        uint256 price = btcMinerPrice;
            require(!btcPaused, "Bitcoin miner minting is paused"); // Check if Bitcoin minting is paused
            require(bitcoin.minersHashing.add(amount) <= bitcoinMinerSupply, "Bitcoin miner supply exceeded");
            require(windmill.currentPowerUsed.add(minerPower.mul(107)) <= windmill.windmillCap, "You must increase your windmill capacity");
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price.mul(amount));
            

            uint256 minerToken = _btcMinerTokenIds.current().add(1);
            miners[minerToken] = Miner({
                
                tokenId: minerToken,
                token: "Bitcoin", // Replace this with the appropriate token name
                name: "JohnnyNewcome", // Miner name
                hashrate: initialHashrate, // Replace this with the appropriate hashrate
                hashMeasured: "TH", // Measured in TerraHashes
                powerConsumption: minerPower.mul(107), // Replace this with the appropriate power consumption
                rewardPerBlock: initialHashrate.mul(btcReward), // Calculate the rewardPerBlock based on hashrate and btcReward
                lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
                accumulated: 0,
                dailyEstimate: initialHashrate.mul(btcReward).mul(dailyBlocks),
                imageURI: _imageURI
                });
                safeMintBtcMiner(msg.sender);

                bitcoin.minersHashing = bitcoin.minersHashing.add(amount);
                bitcoin.minerTokenIds.push(minerToken);
                bitcoin.totalHashrate = bitcoin.totalHashrate.add(initialHashrate.mul(amount));
                bitcoin.totalPowerConsumption = bitcoin.totalPowerConsumption.add(minerPower.mul(107));
                bitcoinMinerSupply ++;

                // Update the windmill's current power consumption
                if (windmill.currentPowerUsed == 0) {
                    windmill.currentPowerUsed = (minerPower.mul(107));
                } else {
                    windmill.currentPowerUsed = windmill.currentPowerUsed.add(minerPower.mul(107));
                }

                minerMints[msg.sender]++;
                referrals[referrer] = msg.sender; // add the msg sender address to referrer's referrals
                claimTokensRewarded[referrer]++; // reward the referrer with 1 claim point for the successful referral
                IClaim(cm).mint(referrer); // reward the referrer with 1 claim token for the successful referral            
    }

    function mintNoReferral(uint256 _pid, string memory _imageURI) public {
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill();

        // Check if the user has a valid windmill based on the returned struct.
        require(userWindmill.tokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Now you can use 'userWindmill.tokenId' to retrieve information about the user's windmill.
        IWindmill.Windmill memory windmill = IWindmill(wm).getWindmill(userWindmill.tokenId);
        // ERC20 paytoken logic
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 amount = 1;
        uint256 price = btcMinerPrice;
            require(!btcPaused, "Bitcoin miner minting is paused"); // Check if Bitcoin minting is paused
            require(bitcoin.minersHashing.add(amount) <= bitcoinMinerSupply, "Bitcoin miner supply exceeded");
            require(windmill.currentPowerUsed.add(minerPower.mul(107)) <= windmill.windmillCap, "You must increase your windmill capacity");
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price.mul(amount));
            
        // Set the new token struct data
            uint256 minerToken = _btcMinerTokenIds.current().add(1);
            miners[minerToken] = Miner({
                
                tokenId: minerToken,
                token: "Bitcoin", // Replace this with the appropriate token name
                name: "JohnnyNewcome", // Miner name
                hashrate: initialHashrate, // Replace this with the appropriate hashrate
                hashMeasured: "TH", // Measured in TerraHashes
                powerConsumption: minerPower.mul(107), // Replace this with the appropriate power consumption
                rewardPerBlock: initialHashrate.mul(btcReward), // Calculate the rewardPerBlock based on hashrate and btcReward
                lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
                accumulated: 0,
                dailyEstimate: initialHashrate.mul(btcReward).mul(dailyBlocks),
                imageURI: _imageURI
                });
                safeMintBtcMiner(msg.sender);

                // Update global Bitcoin miner stats
                bitcoin.minersHashing = bitcoin.minersHashing.add(amount);
                bitcoin.minerTokenIds.push(minerToken);
                bitcoin.totalHashrate = bitcoin.totalHashrate.add(initialHashrate.mul(amount));
                bitcoin.totalPowerConsumption = bitcoin.totalPowerConsumption.add(minerPower.mul(107));
                bitcoinMinerSupply ++;

                minerMints[msg.sender]++;
        
    }

    function boostMinerHash(uint256 tokenId, uint256 _pid) public {
        // Ensure the caller is the owner of the miner
        address owner = ownerOf(tokenId);
        require(tokenId >= 1 && tokenId < 2000, "invalid token Id");
        require(msg.sender == owner, "Not the owner of the token");
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        // Deduct the boost cost from the sender's balance
        uint256 price = btcBoostRate;
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price);

        // Get the windmill details
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill();

        // Check if the user has a valid windmill based on the returned struct.
        require(userWindmill.tokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Now you can use 'userWindmill.tokenId' to retrieve information about the user's windmill.
        IWindmill.Windmill memory windmill = IWindmill(wm).getWindmill(userWindmill.tokenId);

        // Get the miner details
        Miner storage miner = miners[tokenId];
        
        // Update the token stats based on the boosted miner's parameters
            require(windmill.currentPowerUsed.add(21) < windmill.windmillCap, "Windmill capacity has been reached, please increase capacity");
            miner.accumulated = (block.number.sub(miner.lastUpdateBlock).mul(btcReward)).mul(miner.hashrate).add(miner.accumulated);
            miner.hashrate = miner.hashrate.add(hsh);
            miner.powerConsumption = miner.powerConsumption.add(minerPower.mul(21));
            miner.rewardPerBlock = miner.hashrate.mul(btcReward);
            miner.lastUpdateBlock = block.number;
            miner.dailyEstimate = miner.rewardPerBlock.mul(dailyBlocks);
            bitcoin.totalHashrate = bitcoin.totalHashrate.add(1);
            bitcoin.totalPowerConsumption = bitcoin.totalPowerConsumption.add(minerPower.mul(21));
            windmill.currentPowerUsed = windmill.currentPowerUsed.add(minerPower.mul(21));
    }

    // Update the name of a miner
    function updateMinerName(uint256 _tokenId, string memory _newName, uint256 _pid) public {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        require(bytes(_newName).length <= 14, "Name exceeds 14 characters limit");

        address owner = ownerOf(_tokenId);
        require(owner != address(0), "Invalid token Id"); // Check if the token exists
        require(msg.sender == owner, "Not the owner of the token");

        // Deduct the boost cost from the sender's balance
        require(paytoken.balanceOf(msg.sender) >= burnAmount, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(0), burnAmount);

        Miner storage miner = miners[_tokenId];
        miner.name = _newName;
    }


    function claimRewards(uint256 tokenId) public {
        require(_exists(tokenId), "Invalid tokenId");
        uint256 _pid = 0; // wbtc
        address user = msg.sender;
        require(minerHolders[user] == tokenId, "Not the owner of the token");
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill();

        // Check if the user has a valid windmill based on the returned struct.
        require(userWindmill.tokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Now you can use 'userWindmill.tokenId' to retrieve information about the user's windmill.
        IWindmill.Windmill memory windmill = IWindmill(wm).getWindmill(userWindmill.tokenId);
        Miner storage miner = miners[tokenId];
        require(miner.powerConsumption < windmill.windmillCap, "caller does not have required power to claim, please increase your windmill capacity" );
        // Distribute rewards to the user
        uint256 rewards = getPendingRewards(tokenId); // Implement reward calculation
        // Call the appropriate claim function in the DistributionPool contract based on minerType
        IDistributionPool(dp).claim(user, _pid, rewards);
        
        miner.accumulated = 0;
        miner.lastUpdateBlock = block.number;

        // Adjust the total rewards paid according to miner
            bitcoin.totalRewardsPaid = bitcoin.totalRewardsPaid.add(rewards);

        // Emit an event or perform other actions as needed
        emit RewardClaimed(user, tokenId);
    }

    // Retrieve pending rewards for a miner
    function getPendingRewards(uint256 tokenId) public view returns (uint256) {
        Miner storage miner = miners[tokenId];

        uint256 currentBlockNumber = block.number;
        uint256 blocksSinceLastUpdate = currentBlockNumber.sub(miner.lastUpdateBlock);

        // Determine which miners reward is being retrieved
            uint256 rewards = blocksSinceLastUpdate.mul(btcReward).mul(miner.hashrate).add(miner.accumulated).div(10**10);
            return rewards;
    }


    // Safemint

    function safeMintBtcMiner(address to) internal {
        uint256 tokenId = _btcMinerTokenIds.current().add(1);
        _btcMinerTokenIds.increment();
        minerHolders[msg.sender] = tokenId;
        _safeMint(to, tokenId);
    }

    // onlyOwner functions

    // Initialize chest contract
    function initializeDp(
        address _dp
        ) external onlyOwner {
        dp = _dp;
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

    // Function to update the windmill contract address if needed
    function initializeWm(address _wm) public onlyOwner {
        wm = _wm;
    }

    // Function to update the claim token contract address if needed
    function initializeCm(address _cm) public onlyOwner {
        cm = _cm;
    }

    // Pause minting or boosting if necessary
    function toggleBtcPaused() public onlyOwner {
        btcPaused = !btcPaused;
    }

    // Set rate for PROSPECT token used to boost windmill
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    // True Bitcoin hashrate, needs to be set
    function setTruBhsh(uint256 _truB) public onlyOwner {
        truBhsh = _truB;
    }
    // Number of daily Nebula chain blocks, needs to be set
    function setDailyBlocks(uint256 _dBlocks) public onlyOwner {
        dailyBlocks = _dBlocks;
    }

    // Set global emission rates for all miner tokens, using Stat structs to obtain tokenIds for each miner
    // Bitcoin emission rate
    

    function setBtcEmissionRate(uint256 _minedRewards) public onlyOwner {
        uint256 rewardsPerTH = _minedRewards.div(truBhsh); // Convert to the token's precision

        

        uint256[] memory totalBtcMinerTokenIds = bitcoin.minerTokenIds;

        for (uint256 i = 0; i < totalBtcMinerTokenIds.length; i++) {
            uint256 tokenId = totalBtcMinerTokenIds[i];
            Miner storage miner = miners[tokenId];
            // log accumulated rewards before updating global hashrate
            miner.accumulated = (block.number.sub(miner.lastUpdateBlock).mul(btcReward)).mul(miner.hashrate).add(miner.accumulated);
            miner.lastUpdateBlock = block.number;
            // Set the new global reward per block
            btcReward = rewardsPerTH.div(dailyBlocks);
            // Calculate the rewardPerBlock with the token's precision
            miner.rewardPerBlock = btcReward.mul(miner.hashrate);
            miner.dailyEstimate = miner.rewardPerBlock.mul(dailyBlocks);

        }
    }

    function setBtcBoostRate(uint256 _rate) public onlyOwner {
        btcBoostRate = _rate;
    }

    function setBTCMinerPrice(uint256 _price) public onlyOwner {
        btcMinerPrice = _price;
    }

    function setBTCMinerDiscountedPrice(uint256 _price) public onlyOwner {
        discountedPrice = _price;
    }

    function setBurnAmount(uint256 _amount) public onlyOwner {
        burnAmount = _amount;
    }

    // Withdraw PROSPECT tokens
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