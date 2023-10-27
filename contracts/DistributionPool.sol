// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";



contract DistributionPool is Ownable {
    using SafeMath for uint256;

    bool public lock;

    struct TokenInfo {
        IERC20 paytoken;
    }

    TokenInfo[] public AllowedCrypto;
    // Set rate of allowed erc20 token, a rate of 1 would be 1:1 with eth
    mapping(uint256 => uint) public rates;

    // mapping to store allowed contracts
    mapping(address => bool) public allowedContracts;

    constructor() {
    }

    function claim(address user, uint256 _pid, uint256 rewards) external {
        require(lock == false, "lock activated");
        require(_pid < AllowedCrypto.length, "Invalid _pid"); // Ensure _pid is within valid range
        TokenInfo storage token = AllowedCrypto[_pid];
        IERC20 paytoken = token.paytoken;

        require(paytoken.balanceOf(address(this)) >= rewards, "Not enough balance");
        lock = true;

        // Transfer the portion of the payment to the caller
        require(allowedContracts[msg.sender], "Caller does not have permission to call this function");
        paytoken.transfer(user, rewards);
        lock = false;
    }


    // Add an erc20 token to be accepted for payment
    function addCurrency(
        IERC20 _paytoken
        ) public onlyOwner {
        AllowedCrypto.push(
        TokenInfo({paytoken: _paytoken})
        );
    }

    // Set the rate of the erc20 token accepted for payment, first erc20 token set is always pid 0
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    function deposit(uint256 amount, uint256 _pid) public onlyOwner {
        TokenInfo storage token = AllowedCrypto[_pid];
        IERC20 paytoken = token.paytoken;

        require(paytoken.balanceOf(msg.sender) >= amount, "You do not have enough funds.");
        require(paytoken.allowance(msg.sender, address(this)) >= amount, "You must approve the contract to spend your tokens.");

        paytoken.approve(address(this), amount); // Approve the distribution pool contract to spend the required tokens
        // Transfer the portion of the payment to the pickaxes contract (this contract)
        paytoken.transferFrom(msg.sender, address(this), amount);
    }

    // Withdraw erc20 tokens from the contract
    function withdraw (uint256 _pid) public onlyOwner {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transfer(msg.sender, paytoken.balanceOf(address(this)));
    }


    function allowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = true;
    }

    function disallowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = false;
    }
}