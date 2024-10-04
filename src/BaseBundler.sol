// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMulticall} from "./interfaces/IMulticall.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {UNSET_INITIATOR} from "./libraries/ConstantsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to the same contract (self).
/// @dev Every bundler must inherit from this contract.
/// @dev Every bundler inheriting from this contract must have their external functions payable as they will be
/// delegate called by the `multicall` function (which is payable, and thus might pass a non-null ETH value). It is
/// recommended not to rely on `msg.value` as the same value can be reused for multiple calls.
abstract contract BaseBundler is IMulticall {
    using SafeTransferLib for ERC20;

    /* STORAGE */

    /// @notice Keeps track of the bundler's latest bundle initiator.
    /// @dev Also prevents interacting with the bundler outside of an initiated execution context.
    address private _initiator = UNSET_INITIATOR;

    /* MODIFIERS */

    /// @dev Prevents a function to be called outside an initiated `multicall` context and protects a function from
    /// being called by an unauthorized sender inside an initiated multicall context.
    modifier protected() {
        require(_initiator != UNSET_INITIATOR, ErrorsLib.UNINITIATED);
        require(_isSenderAuthorized(), ErrorsLib.UNAUTHORIZED_SENDER);

        _;
    }

    /* PUBLIC */

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() public view returns (address) {
        return _initiator;
    }

    /* EXTERNAL */

    /// @notice Executes a series of delegate calls to the contract itself.
    /// @dev Locks the initiator so that the sender can uniquely be identified in callbacks.
    /// @dev All functions delegatecalled must be `payable` if `msg.value` is non-zero.
    function multicall(bytes[] memory data) external payable {
        require(_initiator == UNSET_INITIATOR, ErrorsLib.ALREADY_INITIATED);

        _initiator = msg.sender;

        _multicall(data);

        _initiator = UNSET_INITIATOR;
    }

    /* INTERNAL */

    /// @dev Executes a series of delegate calls to the contract itself.
    /// @dev All functions delegatecalled must be `payable` if `msg.value` is non-zero.
    function _multicall(bytes[] memory data) internal {
        for (uint256 i; i < data.length; ++i) {
            (bool success, bytes memory returnData) = address(this).delegatecall(data[i]);

            // No need to check that `address(this)` has code in case of success.
            if (!success) _revert(returnData);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function _revert(bytes memory returnData) internal pure {
        uint256 length = returnData.length;
        require(length > 0, ErrorsLib.CALL_FAILED);

        assembly ("memory-safe") {
            revert(add(32, returnData), length)
        }
    }

    /// @dev Returns whether the sender of the call is authorized.
    /// @dev Assumes to be inside a properly initiated `multicall` context.
    function _isSenderAuthorized() internal view virtual returns (bool) {
        return msg.sender == _initiator;
    }

    /// @dev Gives the max approval to `spender` to spend the given `asset` if not already approved.
    /// @dev Assumes that `type(uint256).max` is large enough to never have to increase the allowance again.
    function _approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }
}
