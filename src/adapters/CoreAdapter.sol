// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {SafeERC20, IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "../../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {IBundler3} from "../interfaces/IBundler3.sol";
import {UtilsLib} from "../libraries/UtilsLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Common contract to all Bundler3 adapters.
abstract contract CoreAdapter {
    /* IMMUTABLES */

    /// @notice The address of the Bundler3 contract.
    address public immutable BUNDLER3;

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    constructor(address bundler3) {
        require(bundler3 != address(0), ErrorsLib.ZeroAddress());

        BUNDLER3 = bundler3;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier onlyBundler3() {
        require(msg.sender == BUNDLER3, ErrorsLib.UnauthorizedSender());
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the adapter and should be used afterwards.
    /// @dev Allows the wrapped native contract to transfer native tokens to the adapter.
    receive() external payable virtual {}

    /* ACTIONS */

    /// @notice Transfers native assets.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Pass `type(uint).max` to transfer the adapter's balance
    /// (this allows 0 value transfers).
    function nativeTransfer(address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = address(this).balance;
        else require(amount != 0, ErrorsLib.ZeroAmount());

        if (amount > 0) Address.sendValue(payable(receiver), amount);
    }

    /// @notice Transfers ERC20 tokens.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the adapter's balance (this
    /// allows 0 value transfers).
    function erc20Transfer(address token, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = IERC20(token).balanceOf(address(this));
        else require(amount != 0, ErrorsLib.ZeroAmount());

        if (amount > 0) SafeERC20.safeTransfer(IERC20(token), receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the adapter.
    /// @dev The initiator value being non-zero indicates that a bundle is being processed.
    function initiator() internal view returns (address) {
        return IBundler3(BUNDLER3).initiator();
    }

    /// @notice Calls bundler3.reenter with an already encoded Call array.
    /// @dev Useful to skip an ABI decode-encode step when transmitting callback data.
    /// @param data An abi-encoded Call[].
    function reenterBundler3(bytes calldata data) internal {
        (bool success, bytes memory returnData) = BUNDLER3.call(bytes.concat(IBundler3.reenter.selector, data));
        if (!success) UtilsLib.lowLevelRevert(returnData);
    }
}
