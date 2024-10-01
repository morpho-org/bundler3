// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {BaseBundler} from "./BaseBundler.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import "./interfaces/NamedOffset.sol";
import {TRANSIENT_VARIABLES_PREFIX} from "./libraries/ConstantsLib.sol";

/// @title VariablesBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract to store and read variables to and from transient storage
abstract contract VariablesBundler is BaseBundler {
    /* EXTERNAL */

    function setVariablesWithCall(address target, bytes calldata data, NamedOffset[] calldata namedOffsets)
        external
        protected
    {
        (bool success, bytes memory returnData) = target.staticcall(data);
        if (!success) _revert(returnData);

        for (uint256 i = 0; i < namedOffsets.length; i++) {
            _setVariable(namedOffsets[i].name, readBytesAtOffset(returnData, namedOffsets[i].offset));
        }
    }

    function setVariablesWithCallForceView(address target, bytes calldata data, NamedOffset[] calldata namedOffsets)
        external
        protected
    {
        try this.callAndRevert(target, data) returns (bytes memory returnData) {
            _revert(returnData);
        } catch (bytes memory returnData) {
            for (uint256 i = 0; i < namedOffsets.length; i++) {
                _setVariable(namedOffsets[i].name, readBytesAtOffset(returnData, namedOffsets[i].offset));
            }
        }
    }

    function callAndRevert(address target, bytes calldata data) external returns (bytes memory) {
        (bool success, bytes memory returnData) = target.call(data);
        if (success) {
            _revert(returnData);
        } else {
            assembly ("memory-safe") {
                return(add(returnData, 32), returndatasize())
            }
        }
    }

    function setVariable(bytes32 name, bytes32 data) external protected {
        _setVariable(name, data);
    }

    function getVariable(bytes32 name) external view returns (bytes32) {
        return _getVariable(name);
    }

    /* INTERNAL */

    function _setVariable(bytes32 name, bytes32 value) internal {
        require(name != "", ErrorsLib.NULL_VARIABLE_NAME);
        bytes32 slot = getVariableTransientSlot(name);
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    function _getVariable(bytes32 name) internal view returns (bytes32 value) {
        bytes32 slot = getVariableTransientSlot(name);
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    function readBytesAtOffset(bytes memory data, uint256 offset) internal pure returns (bytes32 currentValue) {
        require(offset <= data.length - 32, ErrorsLib.INVALID_OFFSET);
        assembly {
            currentValue := mload(add(32, add(data, offset)))
        }
    }

    function getVariableTransientSlot(bytes32 name) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(TRANSIENT_VARIABLES_PREFIX, name));
    }
}
