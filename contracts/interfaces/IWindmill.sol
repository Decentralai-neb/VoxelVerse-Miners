// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWindmill {
    // Windmill Data
    struct Windmill {
        uint256 tokenId; // Token Id of windmill
        uint256 currentPowerUsed; // The current amount of power used
        uint256 windmillCap; // The current generating capacity of a windmill
    }

    function checkIfUserHasWindmill() external view returns (Windmill memory);

    function getWindmill(uint256 tokenId) external view returns (Windmill memory);
}