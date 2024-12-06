// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {IBundler, Call} from "../../../src/interfaces/IBundler.sol";

event Initiator(address);

event AllowedToReenter(address);

contract AdapterMock is CoreAdapter {
    constructor(address bundler) CoreAdapter(bundler) {}

    function isProtected() external payable onlyBundler {
        emit AllowedToReenter(IBundler(BUNDLER).allowedToReenter());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackBundler(Call[] calldata calls) external onlyBundler {
        emit AllowedToReenter(IBundler(BUNDLER).allowedToReenter());
        IBundler(BUNDLER).reenter(calls);
        emit AllowedToReenter(IBundler(BUNDLER).allowedToReenter());
    }

    function callbackBundlerWithMulticall() external onlyBundler {
        IBundler(BUNDLER).multicall(new Call[](0));
    }
}
