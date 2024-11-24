// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {Call} from "./Call.sol";

/// @title IBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Bundler.
interface IBundler {
    function multicall(Call[] calldata bundle) external payable;
    function multicallFromModule(Call[] calldata bundle) external payable;
    function currentModule() external view returns (address module);
    function initiator() external view returns (address);
}
