// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseModule} from "../BaseModule.sol";
import {IBundler} from "../interfaces/IBundler.sol";
import {Call} from "../interfaces/Call.sol";

event Initiator(address);

event CurrentModule(address);

contract ModuleMock is BaseModule {
    constructor(address bundler) BaseModule(bundler) {}

    function isProtected() external payable bundlerOnly {
        emit CurrentModule(IBundler(BUNDLER).currentModule());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(initiator());
    }

    function callbackBundler(Call[] calldata calls) external bundlerOnly {
        emit CurrentModule(IBundler(BUNDLER).currentModule());
        IBundler(BUNDLER).multicallFromModule(calls);
        emit CurrentModule(IBundler(BUNDLER).currentModule());
    }

    function callbackBundlerWithMulticall() external bundlerOnly {
        IBundler(BUNDLER).multicall(new Call[](0), new bytes32[](0));
    }

    function emitCurrentModule() external {}
}
