// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IModularBundler} from "../../../src/interfaces/IModularBundler.sol";

library BundleTestLib {
    // Push a bundle call to a module function, with value 0
    function pushModuleCall(bytes[] storage bundle, address module, bytes memory data) internal {
        pushModuleCall(bundle, module, data, 0);
    }

    // Push a bundle call to a module function, with arbitrary value
    function pushModuleCall(bytes[] storage bundle, address module, bytes memory data, uint256 value) internal {
        bundle.push(abi.encodeCall(IModularBundler.callModule, (address(module), data, value)));
    }
}
