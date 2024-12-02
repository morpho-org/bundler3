// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IModuleMock.sol";
import {BaseModule} from "../BaseModule.sol";
import {IBundler} from "../interfaces/IBundler.sol";

contract ModuleMock is BaseModule, IModuleMock {
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
