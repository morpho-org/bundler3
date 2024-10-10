// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseMorphoBundlerModule} from "../modules/BaseMorphoBundlerModule.sol";
import {IBaseBundler} from "../interfaces/IBaseBundler.sol";

event Initiator(address);

event CurrentModule(address);

contract MorphoBundlerModuleMock is BaseMorphoBundlerModule {
    constructor(address bundler) BaseMorphoBundlerModule(bundler) {}

    function isProtected() external payable bundlerOnly {
        emit CurrentModule(IBaseBundler(MORPHO_BUNDLER).currentModule());
    }

    function doRevert(string memory reason) external payable {
        revert(reason);
    }

    function emitInitiator() external payable {
        emit Initiator(initiator());
    }

    function callbackBundler(bytes calldata data) external payable bundlerOnly {
        emit CurrentModule(IBaseBundler(MORPHO_BUNDLER).currentModule());
        IBaseBundler(MORPHO_BUNDLER).multicallFromModule(data);
        emit CurrentModule(IBaseBundler(MORPHO_BUNDLER).currentModule());
    }

    function emitCurrentModule() external payable {}
}
