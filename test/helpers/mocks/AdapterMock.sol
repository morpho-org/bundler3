// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {IInitMulticall, Call} from "../../../src/interfaces/IInitMulticall.sol";

event Initiator(address);

event lastUnreturnedCallee(address);

contract AdapterMock is CoreAdapter {
    constructor(address initMulticall) CoreAdapter(initMulticall) {}

    function isProtected() external payable onlyInitMulticall {
        emit lastUnreturnedCallee(IInitMulticall(BUNDLER).lastUnreturnedCallee());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(_initiator());
    }

    function callbackInitMulticall(Call[] calldata calls) external onlyInitMulticall {
        emit lastUnreturnedCallee(IInitMulticall(BUNDLER).lastUnreturnedCallee());
        IInitMulticall(BUNDLER).reenter(calls);
        emit lastUnreturnedCallee(IInitMulticall(BUNDLER).lastUnreturnedCallee());
    }

    function callbackInitMulticallWithMulticall() external onlyInitMulticall {
        IInitMulticall(BUNDLER).multicall(new Call[](0));
    }

    function emitlastUnreturnedCallee() external {}
}
