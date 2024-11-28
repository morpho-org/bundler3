// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseModule} from "../BaseModule.sol";
import {IBundler, Call} from "../interfaces/IBundler.sol";

event Initiator(address);

event CurrentModule(address);

contract ModuleMock is BaseModule {
    constructor(address bundler) BaseModule(bundler) {}

    function isProtected() external payable onlyBundler {
        emit CurrentModule(IBundler(BUNDLER).currentModule());
    }

    function doRevert(string memory reason) external pure {
        revert(reason);
    }

    function emitInitiator() external {
        emit Initiator(_initiator());
    }

    function callbackBundler(Call[] calldata calls) external onlyBundler {
        emit CurrentModule(IBundler(BUNDLER).currentModule());
        IBundler(BUNDLER).multicallFromModule(calls);
        emit CurrentModule(IBundler(BUNDLER).currentModule());
    }

    function callbackBundlerWithMulticall() external onlyBundler {
        IBundler(BUNDLER).multicall(new Call[](0));
    }

    function emitCurrentModule() external {}
}
