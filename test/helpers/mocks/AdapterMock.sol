// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {CommonBase} from "../../../lib/forge-std/src/Base.sol";
import {IBundler3, Call} from "../../../src/interfaces/IBundler3.sol";

event Initiator(address);

event ReenterHash(bytes32);

contract AdapterMock is CoreAdapter, CommonBase {
    constructor(address bundler3) CoreAdapter(bundler3) {}

    function isProtected() external payable onlyBundler3 {
        emit ReenterHash(IBundler3(BUNDLER3).reenterHash());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackBundler3(Call[] calldata calls) external onlyBundler3 {
        emit ReenterHash(IBundler3(BUNDLER3).reenterHash());
        IBundler3(BUNDLER3).reenter(calls);
        emit ReenterHash(IBundler3(BUNDLER3).reenterHash());
    }

    function callbackBundler3Twice(Call[] calldata calls1, Call[] calldata calls2) external onlyBundler3 {
        IBundler3(BUNDLER3).reenter(calls1);
        IBundler3(BUNDLER3).reenter(calls2);
    }

    function callbackBundler3WithMulticall() external onlyBundler3 {
        IBundler3(BUNDLER3).multicall(new Call[](0));
    }
}
