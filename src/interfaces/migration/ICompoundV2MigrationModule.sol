// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IBaseModule} from "../IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of contract allowing to migrate a position from Compound V2 to Morpho Blue easily.
interface ICompoundV2MigrationModule is IBaseModule {
    function C_ETH() external view returns (address);
    function compoundV2RepayErc20(address cToken, uint256 amount, address onBehalf) external;
    function compoundV2RepayEth(uint256 amount, address onBehalf) external;
    function compoundV2RedeemErc20(address cToken, uint256 amount, address receiver) external;
    function compoundV2RedeemEth(uint256 amount, address receiver) external;
}
