// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IAaveV2} from "../IAaveV2.sol";
import {IBaseModule} from "../IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of contract allowing to migrate a position from Aave V2 to Morpho Blue easily.
interface IAaveV2MigrationModule is IBaseModule {
    function AAVE_V2_POOL() external view returns (IAaveV2);
    function aaveV2Repay(address token, uint256 amount, uint256 interestRateMode, address onBehalf) external;
    function aaveV2Withdraw(address token, uint256 amount, address receiver) external;
}
