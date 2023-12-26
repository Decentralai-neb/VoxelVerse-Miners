// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VvERC20Resources is ERC20Burnable, Ownable {
    address public allowedMinterContract;

    struct ResourceToken {
        string resourceName;
        uint256 id;
        uint256 balance;
    }

    mapping(address => mapping(uint256 => ResourceToken)) public resources; // Access Resource Token struct by address
    mapping(uint256 => ResourceToken) public globalResources; // Access Resource Token struct in general
    mapping(uint256 => uint256) public _resourceSupply;

    constructor()
        ERC20("VvERC20Resources", "VvERC20R")
    {
        ResourceToken memory woodToken = ResourceToken("Wood", 1, 0);
        ResourceToken memory stoneToken = ResourceToken("Stone", 2, 0);
        ResourceToken memory ironToken = ResourceToken("Iron", 3, 0);
        ResourceToken memory goldToken = ResourceToken("Gold", 4, 0);
        ResourceToken memory metalBarToken = ResourceToken("MetalBar", 5, 0);
        ResourceToken memory goldBarToken = ResourceToken("GoldBar", 6, 0);

        resources[msg.sender][1] = woodToken;
        resources[msg.sender][2] = stoneToken;
        resources[msg.sender][3] = ironToken;
        resources[msg.sender][4] = goldToken;
        resources[msg.sender][5] = metalBarToken;
        resources[msg.sender][6] = goldBarToken;
    }

    function setMinterContract(address _minterContract) external onlyOwner {
        allowedMinterContract = _minterContract;
    }
    
    modifier onlyContract() {
        require(msg.sender == allowedMinterContract, "Only the allowed contract can call this function");
        _;
    }

    event ResourceTokenMinted(address indexed holder, uint256 indexed id, uint256 amount);
    event ResourceTokenTransferred(address indexed from, address indexed to, uint256 indexed id, uint256 amount);
    event ResourceTokenBurned(address indexed owner, uint256 indexed id, uint256 amount);
    event TokenBurnedOnBehalf(address indexed owner, uint256 indexed id, uint256 amount);

    function mintResourceToken(address holder, uint256 id, uint256 amount) public onlyOwner {
        string memory resourceName = resources[holder][id].resourceName;

        // Increase the amount of the existing ResourceToken
        resources[holder][id].balance += amount;
        _resourceSupply[id] += amount;

        uint256 _res = id;
        globalResources[_res] = ResourceToken({
            resourceName: resourceName, 
            id: id,
            balance: resources[holder][id].balance 
        });

        emit ResourceTokenMinted(holder, id, resources[holder][id].balance);
        emit Transfer(address(0), holder, amount);
    }

    function mintSmeltedResourceToken(address holder, uint256 id, uint256 amount) public onlyOwner {
        string memory resourceName = resources[holder][id].resourceName;
        uint256 requiredIron = 3;
        uint256 requiredGold = 3;
        uint256 requiredId = 0;
        uint256 requiredAmount = 0;

        if (id == 5) {
            requiredId = 3; // require raw Iron
            requiredAmount = amount * requiredIron;
        } else if (id == 6) {
            requiredId = 4; // require raw Gold
            requiredAmount = amount * requiredGold;
        } 

        require(resources[holder][requiredId].balance >= requiredAmount, "Insufficient requirement balance");

        resources[holder][requiredId].balance -= requiredAmount;
        resources[holder][id].balance += amount; // Increase the balance of the existing ResourceToken
        _resourceSupply[id] += amount;

        uint256 _res = id;
        globalResources[_res] = ResourceToken({
            resourceName: resourceName, 
            id: id,
            balance: resources[holder][id].balance 
        });

        emit ResourceTokenMinted(holder, id, resources[holder][id].balance);
        emit Transfer(address(0), holder, amount);
    }



    function transferResourceToken(address to, uint256 id, uint256 amount) public {
        require(resources[msg.sender][id].balance >= amount, "Insufficient balance to transfer");

        resources[msg.sender][id].balance -= amount;
        resources[to][id].balance += amount;

        emit ResourceTokenTransferred(msg.sender, to, id, amount);
        emit Transfer(msg.sender, to, amount);
    }

    function transferResourceTokenToSell(address from, address to, uint256 id, uint256 amount) external {
        require(resources[from][id].balance >= amount, "Insufficient balance");
        require(resources[to][id].balance + amount >= resources[to][id].balance, "Overflow detected");

        resources[from][id].balance -= amount;
        resources[to][id].balance += amount;

        emit ResourceTokenTransferred(from, to, id, amount);
        emit Transfer(from, to, amount);
    }


    function burnResourceToken(uint256 id, uint256 amount) public {
        require(resources[msg.sender][id].balance >= amount, "Insufficient balance to burn");

        resources[msg.sender][id].balance -= amount;
        _resourceSupply[id] -= amount;

        emit ResourceTokenBurned(msg.sender, id, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    function totalSupplyByResourceId(uint256 id) public view returns (uint256) {
        return _resourceSupply[id];
    }

    function resourceBalanceOf(address account, uint256 id) public view returns (uint256) {
        return resources[account][id].balance;
    }

    function getResourceNameByAccount(uint256 id, address account) public view returns (string memory) {
        return resources[account][id].resourceName;
    }

    function getResourceName(uint256 id) public view returns (string memory) {
        return globalResources[id].resourceName;
    }


    function burnOnBehalf(address owner, uint256 id, uint256 amount) public onlyOwner {
        require(resources[owner][id].balance >= amount, "Insufficient balance");

        // Burn the tokens
        resources[owner][id].balance -= amount;
        _resourceSupply[id] -= amount;

        emit TokenBurnedOnBehalf(owner, id, amount);
        emit Transfer(owner, address(0), amount);
    }
}
