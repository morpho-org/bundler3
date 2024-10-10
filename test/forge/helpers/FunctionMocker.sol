// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {INITIATOR_SLOT, CURRENT_MODULE_SLOT} from "../../../src/libraries/ConstantsLib.sol";

// Pose as existing contracts and make them do unexpected things.
contract FunctionMocker {
    function setInitiator(address _initiator) external {
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, _initiator)
        }
    }

    function setCurrentModule(address module) external {
        assembly ("memory-safe") {
            tstore(CURRENT_MODULE_SLOT, module)
        }
    }
}
