// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseBundler} from "../BaseBundler.sol";
import {IHub} from "../interfaces/IHub.sol";
import {Call} from "../interfaces/Call.sol";

event Initiator(address);

event CurrentBundler(address);

contract BundlerMock is BaseBundler {
    constructor(address hub) BaseBundler(hub) {}

    function isProtected() external payable hubOnly {
        emit CurrentBundler(IHub(HUB).currentBundler());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackHub(Call[] calldata calls) external hubOnly {
        emit CurrentBundler(IHub(HUB).currentBundler());
        IHub(HUB).multicallFromBundler(calls);
        emit CurrentBundler(IHub(HUB).currentBundler());
    }

    function callbackHubWithMulticall() external hubOnly {
        IHub(HUB).multicall(new Call[](0));
    }

    function emitCurrentBundler() external {}
}
