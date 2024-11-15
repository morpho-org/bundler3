// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IBundler} from "./interfaces/IBundler.sol";
import {Math} from "../lib/morpho-utils/src/math/Math.sol";
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
    modifier bundlerOnly() {
        require(msg.sender == BUNDLER, ErrorsLib.UnauthorizedSender(msg.sender));
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the module and should be used afterwards.
    /// @dev Allows the wrapped native contract to send native tokens to the module.
    receive() external payable {}

    /* ACTIONS */

    /// @notice Transfers the minimum between the given `amount` and the module's balance of native asset from the
    /// module to `receiver`.
    /// @dev If the minimum happens to be zero, the transfer is silently skipped.
    /// @dev The receiver must not be the module or the zero address.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Capped at the module's balance.
    function nativeTransfer(address receiver, uint256 amount) external payable bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.ModuleAddress());

        amount = Math.min(amount, address(this).balance);

        ModuleLib.nativeTransfer(receiver, amount);
    }

    /// @notice Transfers the minimum between the given `amount` and the module's balance of `token` from the module
    /// to `receiver`.
    /// @dev If the minimum happens to be zero the transfer is silently skipped.
    /// @dev The receiver must not be the module or the zero address.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer. Capped at the module's balance.
    function erc20Transfer(address token, address receiver, uint256 amount) external bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.ModuleAddress());

        amount = Math.min(amount, ERC20(token).balanceOf(address(this)));

        ModuleLib.erc20Transfer(token, receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the module.
    /// @dev If the caller is not the bundler, the initiator value may be 0.
    function initiator() internal view returns (address) {
        return IBundler(BUNDLER).initiator();
    }

    /// @notice Calls bundler.multicallFromModule with an already encoded Call array.
    /// @dev Useful to skip an ABI decode-encode step when transmitting callback data.
    /// @param data An abi-encoded Call[]
    function multicallBundler(bytes calldata data) internal {
        (bool success, bytes memory returnData) =
            BUNDLER.call(bytes.concat(IBundler.multicallFromModule.selector, data));
        if (!success) {
            ModuleLib.lowLevelRevert(returnData);
        }
    }
}
