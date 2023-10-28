// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IProspectPowerBank is IERC20 {
    function depositProspect(address user, uint256 depositAmount) external;

    function withdrawProspect(address user, uint256 withdrawAmount) external;

    function getUserBalance(address user) external view returns (uint256);
}