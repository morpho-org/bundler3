// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @custom:contact security@morpho.org
/// @notice Interface to common contract to all Bundler modules.
interface IBaseModule {
    function BUNDLER() external view returns (address);
    receive() external payable;
    function erc20Transfer(address token, address receiver, uint256 amount) external;
    function nativeTransfer(address receiver, uint256 amount) external;
}
