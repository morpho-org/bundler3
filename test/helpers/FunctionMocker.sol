// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BUNDLE_HASH_0_SLOT} from "../../src/libraries/ConstantsLib.sol";

// Pose as existing contracts and make them do unexpected things.
contract FunctionMocker {
    function setInitiator(address newInitiator) external {
        assembly {
            tstore(0, newInitiator)
        }
    }

    function setLastUnreturnedCallee(address newLastUnreturnedCallee) external {
        assembly {
            tstore(1, newLastUnreturnedCallee)
        }
    }

    function setBundleHashAtIndex(bytes32 bundleHash, uint256 index) external {
        assembly ("memory-safe") {
            tstore(add(BUNDLE_HASH_0_SLOT, index), bundleHash)
        }
    }
}
