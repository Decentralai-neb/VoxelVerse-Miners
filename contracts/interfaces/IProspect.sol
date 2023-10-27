// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IProspect is IERC20 {
    function mint(address addr, uint256 amount) external;
}