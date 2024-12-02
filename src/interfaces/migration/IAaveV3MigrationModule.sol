// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IAaveV3} from "../IAaveV3.sol";
import {IBaseModule} from "../IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of contract allowing to migrate a position from Aave V3 to Morpho Blue easily.
interface IAaveV3MigrationModule is IBaseModule {
    function AAVE_V3_POOL() external view returns (IAaveV3);
    function aaveV3Repay(address token, uint256 amount, uint256 interestRateMode, address onBehalf) external;
    function aaveV3Withdraw(address token, uint256 amount, address receiver) external;
}
