// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IGenericModule1} from "./IGenericModule1.sol";
// import {MathRayLib} from "./libraries/MathRayLib.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of module contract specific to Ethereum n°1.
interface IEthereumModule1 is IGenericModule1 {
    function DAI() external view returns (address);
    function ST_ETH() external view returns (address);
    function WST_ETH() external view returns (address);
    function MORPHO_TOKEN() external view returns (address);
    function MORPHO_WRAPPER() external view returns (address);

    function morphoWrapperWithdrawTo(address receiver, uint256 amount) external;
    function stakeEth(uint256 amount, uint256 maxSharePriceE27, address referral, address receiver) external;
    function wrapStEth(uint256 amount, address receiver) external;
    function unwrapStEth(uint256 amount, address receiver) external;
}
