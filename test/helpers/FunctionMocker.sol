// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Pose as existing contracts and make them do unexpected things.
contract FunctionMocker {
    function setInitiator(address newInitiator) external {
        assembly {
            tstore(0, newInitiator)
        }
    }

    function setReenterHash(bytes32 newReenterHash) external {
        assembly {
            tstore(1, newReenterHash)
        }
    }
}
