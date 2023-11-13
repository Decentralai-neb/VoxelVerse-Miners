// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPickaxes {
    function getPickaxeMints(address referrer) external view returns (uint);
}