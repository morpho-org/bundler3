// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CoreAdapter} from "../../../src/adapters/CoreAdapter.sol";
import {IMultiexec, Call} from "../../../src/interfaces/IMultiexec.sol";

event Initiator(address);

event lastUnreturnedCallee(address);

contract AdapterMock is CoreAdapter {
    constructor(address multiexec) CoreAdapter(multiexec) {}

    function isProtected() external payable onlyMultiexec {
        emit lastUnreturnedCallee(IMultiexec(BUNDLER).lastUnreturnedCallee());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(_initiator());
    }

    function callbackMultiexec(Call[] calldata calls) external onlyMultiexec {
        emit lastUnreturnedCallee(IMultiexec(BUNDLER).lastUnreturnedCallee());
        IMultiexec(BUNDLER).reenter(calls);
        emit lastUnreturnedCallee(IMultiexec(BUNDLER).lastUnreturnedCallee());
    }

    function callbackMultiexecWithMulticall() external onlyMultiexec {
        IMultiexec(BUNDLER).multicall(new Call[](0));
    }

    function emitlastUnreturnedCallee() external {}
}
