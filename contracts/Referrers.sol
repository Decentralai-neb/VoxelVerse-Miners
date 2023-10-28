// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";



contract Referrers is Ownable {
    // mapping to store allowed contracts
    mapping(address => bool) public allowedContracts;
    // mapping to track miner mints by an address
    mapping (address => uint) public minerMints;
    // mapping to track an addresses referrals
    mapping (address => address) public referrals;
    // mapping to track the number of referrals by an address
    mapping (address => uint) public totalReferrals;

    constructor() {
    }

    function addMinerMints(address user) external {
        minerMints[user]++;
    }

    function addReferrals(address referrer) external {
        totalReferrals[referrer]++;
    }

    function getTotalReferrals(address referrer) external view returns (uint){
        return totalReferrals[referrer];
    }

    function getMinerMints(address referrer) external view returns (uint){
        return minerMints[referrer];
    }

    function allowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = true;
    }

    function disallowContract(address contractAddress) public onlyOwner {
        allowedContracts[contractAddress] = false;
    }
}