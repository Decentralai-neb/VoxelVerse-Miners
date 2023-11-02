// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWindmill {
    struct Windmill {
        uint256 tokenId;
        uint256 currentPowerUsed;
        uint256 windmillCap;
        string imageURI;
    }

    function checkIfUserHasWindmill(address user) external view returns (Windmill memory);
    function getCurrentPowerUsed(uint256 tokenId) external view returns (uint256);
    function getWindmillCap(uint256 tokenId) external view returns (uint256);
    function updateWindmillCurrentPower(uint256 tokenId, uint256 newPower, bool bypassOwnership) external;
    function updateWindmillCap(uint256 tokenId, uint256 newCap) external;
}