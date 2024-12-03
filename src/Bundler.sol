// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler, Call} from "./interfaces/IBundler.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @custom:contact security@morpho.org
/// @notice Enables calling multiple functions in a single call to multiple contracts ("modules").
/// @notice Transiently stores the initiator of the multicall transaction.
/// @notice Transiently stores the current module that is being called.
contract Bundler is IBundler {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    address public transient initiator;

    /// @notice The current module.
    /// @notice A module becomes the current module upon being called.
    address public transient currentModule;

    /* EXTERNAL */

    /// @notice Executes a series of calls to modules.
    /// @dev Locks the initiator so that the sender can be identified by modules.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator == address(0), ErrorsLib.AlreadyInitiated());

        initiator = msg.sender;

        _multicall(bundle);

        initiator = msg.sender;
    }

    /// @notice Executes a series of calls to modules.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the current module.
    /// @param bundle The ordered array of calldata to execute.
    function multicallFromModule(Call[] calldata bundle) external {
        require(msg.sender == currentModule, ErrorsLib.UnauthorizedSender());
        _multicall(bundle);
    }

    /* INTERNAL */

    /// @notice Executes a series of calls to modules.
    function _multicall(Call[] calldata bundle) internal {
        address previousModule = currentModule;

        // TODO add memory-safe-assembly tag
        assembly {
            let fmp := mload(0x40)
            let end := add(0x44, shl(5, bundle.length))
            let calldata_element_id := 0x44

            if bundle.length {
                for {} 1 {} {
                    // Process bundle[i]
                    let o := calldataload(calldata_element_id)
                    let to := calldataload(add(0x44, o))

                    tstore(1, to) // solidity is so bad that tstore(currentModule.offset, to) does not work

                    let value := calldataload(add(0x84, o))
                    let skipRevert := calldataload(add(0xa4, o))

                    // Retrieve bundle[i].data
                    let data_element_id := add(0x44, add(o, calldataload(add(0x64, o))))
                    let len_data := calldataload(data_element_id)
                    calldatacopy(fmp, add(0x20, data_element_id), len_data)

                    let success := call(gas(), to, value, fmp, len_data, 0, 0)

                    if and(iszero(success), iszero(skipRevert)){
                        // TODO forward error properly
                        returndatacopy(fmp, 0x00, returndatasize())
                        revert(fmp, returndatasize())
                    }
                    calldata_element_id := add(calldata_element_id, 0x20)
                    if iszero(lt(calldata_element_id, end)) {break}
                }
            }

        }
        currentModule = previousModule;
    }
}
