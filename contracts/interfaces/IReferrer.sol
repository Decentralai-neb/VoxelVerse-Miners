// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReferrer {

    function addMinerMints(address user) external;

    function addReferrers(address referrer) external;

    function getReferrals(address referrer) external view returns (uint);
    
    function getMinerMints(address referrer) external view returns (uint);
}