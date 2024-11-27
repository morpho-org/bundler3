// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ERC20, SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IBundler} from "./interfaces/IBundler.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @title BaseModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Common contract to all Morpho Modules.
contract BaseModule {
    address public immutable BUNDLER;

    constructor(address bundler) {
        require(bundler != address(0), ErrorsLib.ZeroAddress());

        BUNDLER = bundler;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier onlyBundler() {
        require(msg.sender == BUNDLER, ErrorsLib.UnauthorizedSender(msg.sender));
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the module and should be used afterwards.
    /// @dev Allows the wrapped native contract to send native tokens to the module.
    receive() external payable {}

    /* ACTIONS */

    /// @notice Transfers native assets.
    /// @dev The amount transfered can be zero.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Pass `type(uint).max` to transfer the module's balance.
    function nativeTransfer(address receiver, uint256 amount) external payable onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.ModuleAddress());

        if (amount == type(uint256).max) amount = address(this).balance;

        if (amount > 0) SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /// @notice Transfers ERC20 tokens.
    /// @dev The amount transfered can be zero.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the module's balance.
    function erc20Transfer(address token, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.ModuleAddress());

        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(address(this));

        if (amount > 0) SafeTransferLib.safeTransfer(ERC20(token), receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the module.
    /// @dev The initiator value being non-zero indicates that a bundle is being processed
    function initiator() internal view returns (address) {
        return IBundler(BUNDLER).initiator();
    }

    /// @notice Calls bundler.multicallFromModule with an already encoded Call array.
    /// @dev Useful to skip an ABI decode-encode step when transmitting callback data.
    /// @param data An abi-encoded Call[].
    function multicallBundler(bytes calldata data) internal {
        (bool success, bytes memory returnData) =
            BUNDLER.call(bytes.concat(IBundler.multicallFromModule.selector, data));
        if (!success) {
            ModuleLib.lowLevelRevert(returnData);
        }
    }
}
