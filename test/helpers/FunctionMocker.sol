// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {INITIATOR_SLOT, CURRENT_BUNDLER_SLOT, BUNDLE_HASH_0_SLOT} from "../../src/libraries/ConstantsLib.sol";

// Pose as existing contracts and make them do unexpected things.
contract FunctionMocker {
    function setInitiator(address _initiator) external {
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, _initiator)
        }
    }

    function setCurrentBundler(address bundler) external {
        assembly ("memory-safe") {
            tstore(CURRENT_BUNDLER_SLOT, bundler)
        }
    }

    function setBundleHashAtIndex(bytes32 bundleHash, uint256 index) external {
        assembly ("memory-safe") {
            tstore(add(BUNDLE_HASH_0_SLOT, index), bundleHash)
        }
    }
}
