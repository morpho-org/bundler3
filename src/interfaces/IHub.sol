// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {Call} from "./Call.sol";

/// @title IHub
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Hub.
interface IHub {
    function multicall(Call[] calldata data) external payable;
    function multicallFromBundler(Call[] calldata data) external payable;
    function currentBundler() external view returns (address bundler);
    function initiator() external view returns (address);
}
