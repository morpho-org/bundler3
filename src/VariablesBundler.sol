// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {BaseBundler} from "./BaseBundler.sol";
import "./interfaces/NamedOffset.sol";
import {BytesLib} from "./libraries/BytesLib.sol";
import {VariablesLib} from "./libraries/VariablesLib.sol";

/// @title VariablesBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract to store and read variables to and from transient storage
abstract contract VariablesBundler is BaseBundler {
    using BytesLib for bytes;
    /* EXTERNAL */

    function setVariablesWithCall(address target, bytes calldata data, NamedOffset[] calldata namedOffsets)
        external
        protected
    {
        (bool success, bytes memory returnData) = target.staticcall(data);
        if (!success) _revert(returnData);

        for (uint256 i = 0; i < namedOffsets.length; i++) {
            VariablesLib.set(namedOffsets[i].name, returnData.get(namedOffsets[i].offset));
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
                VariablesLib.set(namedOffsets[i].name, returnData.get(namedOffsets[i].offset));
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

    function setVariable(bytes32 name, uint256 data) external protected {
        VariablesLib.set(name, data);
    }

    function getVariable(bytes32 name) external view returns (uint256) {
        return VariablesLib.get(name);
    }
}
