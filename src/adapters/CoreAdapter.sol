// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {ERC20, SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {IInitMulticall} from "../interfaces/IInitMulticall.sol";
import {UtilsLib} from "../libraries/UtilsLib.sol";

/// @custom:contact security@morpho.org
/// @notice Common contract to all InitMulticall adapters.
abstract contract CoreAdapter {
    /* IMMUTABLES */

    /// @notice The address of the InitMulticall contract.
    address public immutable BUNDLER;

    /* CONSTRUCTOR */

    /// @param initMulticall The address of the InitMulticall contract.
    constructor(address initMulticall) {
        require(initMulticall != address(0), ErrorsLib.ZeroAddress());

        BUNDLER = initMulticall;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier onlyInitMulticall() {
        require(msg.sender == BUNDLER, ErrorsLib.UnauthorizedSender());
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the adapter and should be used afterwards.
    /// @dev Allows the wrapped native contract to transfer native tokens to the adapter.
    receive() external payable virtual {}

    /* ACTIONS */

    /// @notice Transfers native assets.
    /// @dev The amount transfered can be zero.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Pass `type(uint).max` to transfer the adapter's balance.
    function nativeTransfer(address receiver, uint256 amount) external onlyInitMulticall {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /// @notice Transfers ERC20 tokens.
    /// @dev The amount transfered can be zero.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the adapter's balance.
    function erc20Transfer(address token, address receiver, uint256 amount) external onlyInitMulticall {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeTransferLib.safeTransfer(ERC20(token), receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the adapter.
    /// @dev The initiator value being non-zero indicates that a bundle is being processed.
    function _initiator() internal view returns (address) {
        return IInitMulticall(BUNDLER).initiator();
    }

    /// @notice Calls initMulticall.reenter with an already encoded Call array.
    /// @dev Useful to skip an ABI decode-encode step when transmitting callback data.
    /// @param data An abi-encoded Call[].
    function _reenterInitMulticall(bytes calldata data) internal {
        (bool success, bytes memory returnData) = BUNDLER.call(bytes.concat(IInitMulticall.reenter.selector, data));
        if (!success) UtilsLib.lowLevelRevert(returnData);
    }
}
