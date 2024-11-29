// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ERC20, SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IBundler} from "./interfaces/IBundler.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";

/// @custom:contact security@morpho.org
/// @notice Common contract to all Bundler modules.
abstract contract BaseModule {
    address public immutable BUNDLER;

    constructor(address bundler) {
        require(bundler != address(0), ErrorsLib.ZeroAddress());

        BUNDLER = bundler;
    }

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier onlyBundler() {
        require(msg.sender == BUNDLER, ErrorsLib.UnauthorizedSender());
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the module and should be used afterwards.
    /// @dev Allows the wrapped native contract to transfer native tokens to the module.
    receive() external payable {}

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the module.
    /// @dev The initiator value being non-zero indicates that a bundle is being processed.
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
