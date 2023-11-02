// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract ProspectPowerBank is Ownable {

    bool public lock;

    struct TokenInfo {
        IERC20 prospectToken;
    }

    TokenInfo[] public AllowedCrypto;
    // Set rate of allowed erc20 token, a rate of 1 would be 1:1 with eth
    mapping(uint256 => uint) public rates;

    // mapping to store allowed contracts
    mapping(address => bool) public allowedContracts;

    // mapping to track individual balances of Prospect Token
    mapping(address => uint256) public userBalance;

    constructor() {
    }

    function withdrawProspect(address user, uint256 withdrawAmount) external {
        uint256 _pid = 0;
        require(lock == false, "lock activated");
        require(_pid < AllowedCrypto.length, "Invalid _pid"); // Ensure _pid is within valid range
        TokenInfo storage token = AllowedCrypto[_pid];
        IERC20 prospectToken = token.prospectToken;

        require(prospectToken.balanceOf(address(this)) >= withdrawAmount, "Not enough balance");
        require(withdrawAmount >= userBalance[user], "Amount exceeds your balance");

        userBalance[user] = userBalance[user] - (withdrawAmount); // Update the user's balance
        lock = true;

        // Transfer the portion of the payment to the caller
        require(allowedContracts[msg.sender], "Caller does not have permission to call this function");
        prospectToken.transfer(user, withdrawAmount);
        lock = false;
    }

    function depositProspect(address user, uint256 depositAmount) external {
        require(allowedContracts[msg.sender], "Caller does not have permission to call this function");
        uint256 _pid = 0;
        TokenInfo storage token = AllowedCrypto[_pid];
        IERC20 prospectToken = token.prospectToken;

        require(prospectToken.balanceOf(user) >= depositAmount, "You do not have enough funds.");
        require(prospectToken.allowance(user, address(this)) >= depositAmount, "You must approve the contract to spend your tokens.");

        prospectToken.approve(address(this), depositAmount); // Approve the Prospect Powerbank contract to spend the required tokens
        // Transfer the portion of the payment to the pickaxes contract (this contract)
        prospectToken.transferFrom(msg.sender, address(this), depositAmount);

        // update the user's balance
        userBalance[user] = userBalance[user] + (depositAmount);
    }

    function getUserBalance(address user) external view returns (uint256) {
        return userBalance[user];
    }



    // Add an erc20 token to be accepted for payment
    function addCurrency(
        IERC20 _prospectToken
        ) public onlyOwner {
        AllowedCrypto.push(
        TokenInfo({prospectToken: _prospectToken})
        );
    }

    // Set the rate of the erc20 token accepted for payment, first erc20 token set is always pid 0
    function setRate(uint256 _pid, uint _rate) public onlyOwner {
        rates[_pid] = _rate;
    }

    

    // Withdraw erc20 tokens from the contract
    function withdrawDAO (uint256 _pid) public onlyOwner {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 prospectToken;
        prospectToken = tokens.prospectToken;
        prospectToken.transfer(msg.sender, prospectToken.balanceOf(address(this)));
    }


    function allowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = true;
    }

    function disallowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = false;
    }
}