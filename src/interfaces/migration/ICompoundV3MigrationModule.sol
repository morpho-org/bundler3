// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IBaseModule} from "../IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of contract allowing to migrate a position from Compound V3 to Morpho Blue easily.
interface ICompoundV3MigrationModule is IBaseModule {
    function compoundV3Repay(address instance, uint256 amount, address onBehalf) external;
    function compoundV3WithdrawFrom(address instance, address asset, uint256 amount, address receiver) external;
}
