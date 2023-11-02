// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISkaleMiner {
    function mintWithReferral(address user, uint256 _pid, uint256 windmillToken) external;

    function getMinerMints(address referrer) external view returns (uint);
}