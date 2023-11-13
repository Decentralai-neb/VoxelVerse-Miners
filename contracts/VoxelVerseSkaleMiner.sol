// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/Base64.sol";
import "./interfaces/IDistributionPool.sol";
import "./interfaces/IWindmill.sol";
import "./interfaces/IStone.sol";
import "./interfaces/IWood.sol";

import "hardhat/console.sol";




contract VoxelVerseSkaleMiner is ERC721, Ownable {
    using Counters for Counters.Counter;

    // event handling
    event TokensMinted(address indexed owner, uint256 amount);
    event MinerStarted(string minerType, address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 tokenId);

    mapping (address => address) public skaleMinerReferrals;
    mapping (address => uint) public claimTokensRewarded;
    mapping (address => uint) public minerMints;

    bool public sklPaused;

    // Individual counters for each miner
    Counters.Counter private _sklMinerTokenIds;

    // Miner supply control
    uint256 public skaleMinerSupply = 2000;

    // Pricing 
    uint256 public sklMinerPrice;
    uint256 public discountedPrice;
    uint256 public claimPrice;
    uint256 public burnAmount;

    // Hashrate pricing
    uint256 public sklBoostRate;

    // used for calculating emission rate per block
    uint256 public truSklHsh; 
    uint256 public dailyBlocks;
    uint256 initialHashrate = 5; // the initial hashrate of a miner once minted
    uint256 public constant hsh = 1; // hashrate
    uint256 public constant minerPower = 1; // Used for miner power calculations

    // handle CLAIM payments
    struct ClaimTokenInfo {
        IERC20 claimtoken;
    }

    ClaimTokenInfo[] public AllowedClaimCrypto;
    mapping(uint256 => uint) public claimRate;

    // handle PROSPECT and USDC payments
    struct TokenInfo {
        IERC20 paytoken;
        string name;
    }

    TokenInfo[] public AllowedCrypto;
    mapping(uint256 => uint) public rates;
    address public dp; // distribution pool
    address public wm; // windmill contract

    // Emission rates, can be modified by owner or controller
    uint256 public sklReward;

    // Miner Data
    struct Miner {
        string token; // Token being mined by miner
        uint256 tokenId; // Token Id of miner
        string name; // Name of miner set by owner
        uint256 hashrate; // Miner hashrate
        string hashMeasured; // Hashrate measured in GH, TH or VH
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
    struct SkaleStats {
        uint256 minersHashing; // number of miners hashing
        uint256 totalHashrate; // the total hashrate of all Skale miners
        uint256[] minerTokenIds; // Used for updating global emission rate data across all miners
        uint256 totalPowerConsumption;
        uint256 totalRewardsPaid;
    }
    SkaleStats public skale;

    constructor() ERC721("VoxelVerseSkaleMiner", "VMSKL") {
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
                ' -- VoxelVerse Skale Miner #: ',
                Strings.toString(_tokenId),
                '", "description": "Mine more blocks with your Crypto Miner", "image": "',
                imageURI, // Use the dynamically generated imageURI
                '", "attributes": [ { "trait_type": "Hashrate", "value": ',strHashrate,', ',minerToken.hashMeasured,'}]}'
            )
        );

        string memory itemUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return itemUri;
    }



    modifier whenSklNotPaused() {
        require(!sklPaused, "Skale miner minting is paused");
        _;
    }

    function mintWithReferrer(address user, uint256 _pid, uint256 windmillToken) external {
         // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill(user);
        uint256 windmillTokenId = userWindmill.tokenId; // Store the windmill tokenId

        // Check if the user has at least one windmill
        require(windmillTokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Get the current power used and windmill cap
        uint256 currentPower = IWindmill(wm).getCurrentPowerUsed(windmillToken);
        uint256 cap = IWindmill(wm).getWindmillCap(windmillToken);

        // Check if the user has enough capacity before minting
        require(currentPower + (minerPower * 10) <= cap, "You must increase your windmill capacity");

        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 amount = 1;
        uint256 price = discountedPrice;
        require(!sklPaused, "Skale miner minting is paused");
        require(skale.minersHashing + (amount) <= skaleMinerSupply, "Skale miner supply exceeded");

        // Transfer the payment
        require(paytoken.balanceOf(user) >= price, "Insufficient funds");
        paytoken.transferFrom(user, address(this), price * amount);

        uint256 minerToken = _sklMinerTokenIds.current() + 1;
        string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
        miners[minerToken] = Miner({
            tokenId: minerToken,
            token: "Skale", // Replace this with the appropriate token name
            name: "JohnnyNewcome", // Miner name
            hashrate: initialHashrate, // Replace this with the appropriate hashrate
            hashMeasured: "TH", // Measured in TerraHashes
            powerConsumption: minerPower * 10, // Replace this with the appropriate power consumption
            rewardPerBlock: initialHashrate * sklReward, // Calculate the rewardPerBlock based on hashrate and btcReward
            lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
            accumulated: 0,
            dailyEstimate: initialHashrate * sklReward * dailyBlocks,
            imageURI: string(abi.encodePacked(baseImageURI, Strings.toString(minerToken), ".png"))
        });

        safeMintSklMiner(user);

        skale.minersHashing = skale.minersHashing + amount;
        skale.minerTokenIds.push(minerToken);
        skale.totalHashrate = skale.totalHashrate + (initialHashrate * amount);
        skale.totalPowerConsumption = skale.totalPowerConsumption + (minerPower * 10);
        skaleMinerSupply++;

            uint256 newPower = minerPower * 10;
            uint256 totalPower = currentPower + newPower;
            // Update the windmill's current power used and windmill cap
            IWindmill(wm).updateWindmillCurrentPower(windmillToken, totalPower, true);
            minerMints[msg.sender]++;
    }


    function mintNoReferral(uint256 _pid, uint256 windmillToken) public {
        address user = msg.sender;
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill(user);
        uint256 windmillTokenId = userWindmill.tokenId; // Store the windmill tokenId

        // Check if the user has at least one windmill
        require(windmillTokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Get the current power used and windmill cap
        uint256 currentPower = IWindmill(wm).getCurrentPowerUsed(windmillToken);
        uint256 cap = IWindmill(wm).getWindmillCap(windmillToken);

        // Check if the user has enough capacity before minting
        require(currentPower + (minerPower * 10) <= cap, "You must increase your windmill capacity");

            // ERC20 paytoken logic
            TokenInfo storage tokens = AllowedCrypto[_pid];
            IERC20 paytoken;
            paytoken = tokens.paytoken;
            uint256 amount = 1;
            uint256 price = sklMinerPrice;
            require(!sklPaused, "Bitcoin miner minting is paused");
            require(skale.minersHashing + amount <= skaleMinerSupply, "Bitcoin miner supply exceeded");
            // Transfer payment
            require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
            paytoken.transferFrom(msg.sender, address(this), price * amount);

            // Set the new token struct data
            uint256 minerToken = _sklMinerTokenIds.current() + 2000;

            string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
            miners[minerToken] = Miner({
                tokenId: minerToken,
                token: "Skale", // Replace this with the appropriate token name
                name: "JohnnyNewcome", // Miner name
                hashrate: initialHashrate, // Replace this with the appropriate hashrate
                hashMeasured: "VH", // Measured in TerraHashes
                powerConsumption: minerPower * 10, // Replace this with the appropriate power consumption
                rewardPerBlock: initialHashrate * sklReward, // Calculate the rewardPerBlock based on hashrate and sklReward
                lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
                accumulated: 0,
                dailyEstimate: initialHashrate * sklReward * dailyBlocks,
                imageURI: string(abi.encodePacked(baseImageURI, Strings.toString(minerToken), ".png"))
            });

            safeMintSklMiner(msg.sender);

            // Update global Bitcoin miner stats
            skale.minersHashing = skale.minersHashing + amount;
            skale.minerTokenIds.push(minerToken);
            skale.totalHashrate = skale.totalHashrate + (initialHashrate * amount);
            skale.totalPowerConsumption = skale.totalPowerConsumption + (minerPower * 10);
            skaleMinerSupply++;
            
            uint256 newPower = minerPower * 10;
            uint256 totalPower = currentPower + newPower;
            // Update the windmill's current power used and windmill cap
            IWindmill(wm).updateWindmillCurrentPower(windmillToken, totalPower, true);

            minerMints[msg.sender]++;
            }

    // Claim Miner
    
    function claimMiner(uint256 _pid, uint256 windmillToken) public {
        address user = msg.sender;
        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill(user);
        uint256 windmillTokenId = userWindmill.tokenId; // Store the windmill tokenId

        // Check if the user has at least one windmill
        require(windmillTokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Get the current power used and windmill cap
        uint256 currentPower = IWindmill(wm).getCurrentPowerUsed(windmillToken);
        uint256 cap = IWindmill(wm).getWindmillCap(windmillToken);

        // Check if the user has enough capacity before minting
        require(currentPower + (minerPower * 10) <= cap, "You must increase your windmill capacity");

            // ERC20 paytoken logic
             ClaimTokenInfo storage tokens = AllowedClaimCrypto[_pid];
            IERC20 claimtoken;
            claimtoken = tokens.claimtoken;
            uint256 amount = 1;
            uint256 price = claimPrice;
            require(!sklPaused, "Bitcoin miner minting is paused");
            require(skale.minersHashing + amount <= skaleMinerSupply, "Bitcoin miner supply exceeded");
            // Transfer payment
            require(claimtoken.balanceOf(user) >= price, "Insufficient funds");
            claimtoken.transferFrom(user, address(this), price * amount);

            // Set the new token struct data
            uint256 minerToken = _sklMinerTokenIds.current() + 2000;

            string memory baseImageURI = "https://pickaxecrypto.mypinata.cloud/ipfs/Qma9qoWfYLK1gwrejpk7st4wt7V82YxoDy9MwLESH4HkY4/";
            miners[minerToken] = Miner({
                tokenId: minerToken,
                token: "Skale", // Replace this with the appropriate token name
                name: "JohnnyNewcome", // Miner name
                hashrate: initialHashrate, // Replace this with the appropriate hashrate
                hashMeasured: "VH", // Measured in TerraHashes
                powerConsumption: minerPower * 10, // Replace this with the appropriate power consumption
                rewardPerBlock: initialHashrate * sklReward, // Calculate the rewardPerBlock based on hashrate and sklReward
                lastUpdateBlock: block.number, // Initialize the lastUpdateBlock with the current block
                accumulated: 0,
                dailyEstimate: initialHashrate * sklReward * dailyBlocks,
                imageURI: string(abi.encodePacked(baseImageURI, Strings.toString(minerToken), ".png"))
            });

            safeMintSklMiner(msg.sender);

            // Update global Bitcoin miner stats
            skale.minersHashing = skale.minersHashing + amount;
            skale.minerTokenIds.push(minerToken);
            skale.totalHashrate = skale.totalHashrate + (initialHashrate * amount);
            skale.totalPowerConsumption = skale.totalPowerConsumption + (minerPower * 10);
            skaleMinerSupply++;
            
            uint256 newPower = minerPower * 10;
            uint256 totalPower = currentPower + newPower;
            // Update the windmill's current power used and windmill cap
            IWindmill(wm).updateWindmillCurrentPower(windmillToken, totalPower, true);

            minerMints[msg.sender]++;
            }
    function boostMinerHash(uint256 tokenId, uint256 _pid, uint256 windmillToken) public {
        // Ensure the caller is the owner of the miner
        address owner = ownerOf(tokenId);
        require(tokenId >= 2000 && tokenId < 3000, "Invalid token Id");
        require(msg.sender == owner, "Not the owner of the token");

        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken = tokens.paytoken;

        // Check if the caller owns a windmill
        IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill(owner);
        uint256 windmillTokenId = userWindmill.tokenId; // Store the windmill tokenId

        // Check if the user has at least one windmill
        require(windmillTokenId > 0, "Caller must own at least one windmill to mint a miner");

        // Get the current power used and windmill cap
        uint256 currentPower = IWindmill(wm).getCurrentPowerUsed(windmillToken);
        uint256 cap = IWindmill(wm).getWindmillCap(windmillToken);

        // Check if the user has enough capacity before boosting
        require(currentPower + (minerPower * 5) <= cap, "You must increase your windmill capacity");

        uint256 price = sklBoostRate;
        require(paytoken.balanceOf(msg.sender) >= price, "Insufficient funds");
        paytoken.transferFrom(msg.sender, address(this), price);

        // Get the miner details
        Miner storage miner = miners[tokenId];

        // Update the token stats based on the boosted miner's parameters
        miner.accumulated += (block.number - miner.lastUpdateBlock) * miner.hashrate;
        miner.hashrate += hsh;
        miner.powerConsumption += (minerPower * 5);
        miner.rewardPerBlock = miner.hashrate * sklReward;
        miner.lastUpdateBlock = block.number;
        miner.dailyEstimate = miner.rewardPerBlock * dailyBlocks;

            uint256 newPower = minerPower * 5;
            uint256 totalPower = currentPower + newPower;
            // Update the windmill's current power used and windmill cap
            IWindmill(wm).updateWindmillCurrentPower(windmillToken, totalPower, true);

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

        // Check if the caller owns a windmill
            IWindmill.Windmill memory userWindmill = IWindmill(wm).checkIfUserHasWindmill(user);

            // Check if the user has at least one windmill
            require(userWindmill.tokenId > 0, "Caller must own at least one windmill to mint a miner");

            // Access the windmill data directly using userWindmill.tokenId
            require(userWindmill.currentPowerUsed + (minerPower * 10) <= userWindmill.windmillCap, "You must increase your windmill capacity");
        // Get the miner's tokenId from the function parameter
        uint256 minerTokenId = tokenId;


        // Distribute rewards to the user
        uint256 rewards = getPendingRewards(minerTokenId); // Implement reward calculation

        // Call the appropriate claim function in the DistributionPool contract based on minerType
        IDistributionPool(dp).claim(user, _pid, rewards);

        // Reset miner's accumulated rewards and update the last update block
        miners[minerTokenId].accumulated = 0;
        miners[minerTokenId].lastUpdateBlock = block.number;

        // Adjust the total rewards paid according to miner
        skale.totalRewardsPaid += rewards;

        // Emit an event or perform other actions as needed
        emit RewardClaimed(user, minerTokenId);
    }



    // Retrieve pending rewards for a miner
    function getPendingRewards(uint256 tokenId) public view returns (uint256) {
        Miner storage miner = miners[tokenId];

        uint256 currentBlockNumber = block.number;
        uint256 blocksSinceLastUpdate = currentBlockNumber - miner.lastUpdateBlock;

        // Determine which miners reward is being retrieved
            uint256 rewards = blocksSinceLastUpdate * sklReward * miner.hashrate + miner.accumulated / 10**10;
            return rewards;
    }

    function getMinerMints(address referrer) external view returns (uint){
        return minerMints[referrer];
    }


    // Safemint

    function safeMintSklMiner(address to) internal {
        uint256 tokenId = _sklMinerTokenIds.current() + 2000;
        _sklMinerTokenIds.increment();
        minerHolders[msg.sender] = tokenId;
        _safeMint(to, tokenId);
    }

    // onlyOwner functions

    // Initialize distribution pool contract
    function initializeDp(
        address _dp
        ) external onlyOwner {
        dp = _dp;
    }

    function addClaimToken(
        IERC20 _claimtoken
    ) public onlyOwner {
        AllowedClaimCrypto.push(
            ClaimTokenInfo({
                claimtoken: _claimtoken
            })
        );
    }

    // Update the claim token address
    function updateClaimToken(uint256 _pid, IERC20 _newClaimtoken) public onlyOwner {
        require(_pid < AllowedClaimCrypto.length, "Invalid pid");
        
        ClaimTokenInfo storage claimTokenInfo = AllowedClaimCrypto[_pid];
        claimTokenInfo.claimtoken = _newClaimtoken;
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

    // Pause minting or boosting if necessary
    function toggleSklPaused() public onlyOwner {
        sklPaused = !sklPaused;
    }

    // Set rate for PROSPECT token used to boost windmill
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    // True Bitcoin hashrate, needs to be set
    function setTruSklhsh(uint256 _truSkl) public onlyOwner {
        truSklHsh = _truSkl;
    }
    // Number of daily Nebula chain blocks, needs to be set
    function setDailyBlocks(uint256 _dBlocks) public onlyOwner {
        dailyBlocks = _dBlocks;
    }

    // Set global emission rates for all miner tokens, using Stat structs to obtain tokenIds for each miner
    // Bitcoin emission rate
    

    function setSklEmissionRate(uint256 _minedRewards) public onlyOwner {
        uint256 rewardsPerTH = _minedRewards / truSklHsh; // Convert to the token's precision

        

        uint256[] memory totalSklMinerTokenIds = skale.minerTokenIds;

        for (uint256 i = 0; i < totalSklMinerTokenIds.length; i++) {
            uint256 tokenId = totalSklMinerTokenIds[i];
            Miner storage miner = miners[tokenId];
            // log accumulated rewards before updating global hashrate
            miner.accumulated = (block.number - miner.lastUpdateBlock * sklReward) * miner.hashrate + miner.accumulated;
            miner.lastUpdateBlock = block.number;
            // Set the new global reward per block
            sklReward = rewardsPerTH / dailyBlocks;
            // Calculate the rewardPerBlock with the token's precision
            miner.rewardPerBlock = sklReward * miner.hashrate;
            miner.dailyEstimate = miner.rewardPerBlock * dailyBlocks;

        }
    }

    function setSklBoostRate(uint256 _rate) public onlyOwner {
        sklBoostRate = _rate;
    }

    function setSKLMinerPrice(uint256 _price) public onlyOwner {
        sklMinerPrice = _price;
    }

    function setSKLMinerDiscountedPrice(uint256 _price) public onlyOwner {
        discountedPrice = _price;
    }

    function setBurnAmount(uint256 _amount) public onlyOwner {
        burnAmount = _amount;
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