// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {CommonBase} from "../../../lib/forge-std/src/Base.sol";
import {IBundler, Call} from "../../../src/interfaces/IBundler.sol";

event Initiator(address);

event ReenterHash(bytes32);

contract AdapterMock is CoreAdapter, CommonBase {
    constructor(address bundler) CoreAdapter(bundler) {}

    function isProtected() external payable onlyBundler {
        emit ReenterHash(IBundler(BUNDLER).reenterHash());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackBundler(Call[] calldata calls) external onlyBundler {
        emit ReenterHash(IBundler(BUNDLER).reenterHash());
        IBundler(BUNDLER).reenter(calls);
        emit ReenterHash(IBundler(BUNDLER).reenterHash());
    }

    function callbackBundlerTwice(Call[] calldata calls1, Call[] calldata calls2) external onlyBundler {
        IBundler(BUNDLER).reenter(calls1);
        IBundler(BUNDLER).reenter(calls2);
    }

    function callbackBundlerFrom(Call[] calldata calls, address from) external onlyBundler {
        vm.prank(from);
        IBundler(BUNDLER).reenter(calls);
    }

    function callbackBundlerWithMulticall() external onlyBundler {
        IBundler(BUNDLER).multicall(new Call[](0));
    }
}
