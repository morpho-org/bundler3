// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @notice Struct containing all the data needed to make a call.
struct Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
}

/// @custom:contact security@morpho.org
interface IBundler {
    function multicall(Call[] calldata) external payable;
    function reenter(Call[] calldata) external;
    function lastUnreturnedCallee() external view returns (address);
    function initiator() external view returns (address);
}
