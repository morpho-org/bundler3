// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {IBundler, Call} from "../../../src/interfaces/IBundler.sol";

event Initiator(address);

event reenterSender(address);

contract AdapterMock is CoreAdapter {
    constructor(address bundler) CoreAdapter(bundler) {}

    function isProtected() external payable onlyBundler {
        emit reenterSender(IBundler(BUNDLER).reenterSender());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackBundler(Call[] calldata calls) external onlyBundler {
        emit reenterSender(IBundler(BUNDLER).reenterSender());
        IBundler(BUNDLER).reenter(calls);
        emit reenterSender(IBundler(BUNDLER).reenterSender());
    }

    function callbackBundlerTwice(Call[] calldata calls1, Call[] calldata calls2) external onlyBundler {
        IBundler(BUNDLER).reenter(calls1);
        IBundler(BUNDLER).reenter(calls2);
    }

    function callbackBundlerWithMulticall() external onlyBundler {
        IBundler(BUNDLER).multicall(new Call[](0));
    }

    function emitReenterSender() external {}
}
