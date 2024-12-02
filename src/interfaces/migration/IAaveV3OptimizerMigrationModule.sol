// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IAaveV3Optimizer} from "../IAaveV3Optimizer.sol";
import {IBaseModule} from "../IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of contract allowing to migrate a position from AaveV3 Optimizer to Morpho Blue easily.
interface IAaveV3OptimizerMigrationModule is IBaseModule {
    function AAVE_V3_OPTIMIZER() external view returns (IAaveV3Optimizer);
    function aaveV3OptimizerRepay(address underlying, uint256 amount, address onBehalf) external;
    function aaveV3OptimizerWithdraw(address underlying, uint256 amount, uint256 maxIterations, address receiver)
        external;
    function aaveV3OptimizerWithdrawCollateral(address underlying, uint256 amount, address receiver) external;
}
