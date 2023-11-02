// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IClaim.sol";
import "./interfaces/IBitcoinMiner.sol";
import "./interfaces/ISkaleMiner.sol";




contract Referrers is Ownable {
    // mapping to track an addresses referrals
    mapping (address => address) public referrals;
    // mapping to track the number of referrals by an address
    mapping (address => uint) public totalReferrals;
    // mapping to track the number of claim tokens accumulated
    mapping (address => uint) public claimTokensReceived;
    // claim token contract
    address public cm; // claim token contract
    address public bm; // bitcoin miner contract
    address public sm; // skale miner contract

    constructor() {
    }

    function getTotalReferrals(address referrer) external view returns (uint){
        return totalReferrals[referrer];
    }

    function getClaimTokensReceived(address referrer) external view returns (uint){
        return claimTokensReceived[referrer];
    }

     function mintBmWithReferral(uint256 _pid, address referrer, uint256 windmillToken) public {

            address user = msg.sender;

            // Check if referrer address is valid
            if (referrer != address(0)) {
                require(referrer != user, "Cannot refer yourself");

                // Retrieve the referrer's minerMints using minerMints mapping
                uint256 referrerMints = IBitcoinMiner(bm).getMinerMints(referrer);

                require(referrerMints > 0, "Referrer has not minted a miner");
            }

            IBitcoinMiner(bm).mintWithReferral(user, _pid, windmillToken);
            
            IClaim(cm).mint(referrer); // reward the referrer with 1 claim token for the successful referral
            claimTokensReceived[referrer]++;
            totalReferrals [referrer]++;
            referrals[referrer] = user;
        }

    function mintSmWithReferral(uint256 _pid, address referrer, uint256 windmillToken) public {

            address user = msg.sender;

            // Check if referrer address is valid
            if (referrer != address(0)) {
                require(referrer != user, "Cannot refer yourself");

                // Retrieve the referrer's minerMints using minerMints mapping
                uint256 referrerMints = ISkaleMiner(sm).getMinerMints(referrer);

                require(referrerMints > 0, "Referrer has not minted a miner");
            }

            ISkaleMiner(sm).mintWithReferral(user, _pid, windmillToken);
            
            IClaim(cm).mint(referrer); // reward the referrer with 1 claim token for the successful referral
            claimTokensReceived[referrer]++;
            totalReferrals [referrer]++;
            referrals[referrer] = user;
        }

    // Function to update the claim token contract address if needed
    function initializeCm(address _cm) public onlyOwner {
        cm = _cm;
    }

    // Function to initialize and update the bitcoin miner contract address if needed
    function initializeBm(address _bm) public onlyOwner {
        bm = _bm;
    }

    // Function to initialize and update the bitcoin miner contract address if needed
    function initializeSm(address _sm) public onlyOwner {
        sm = _sm;
    }
}