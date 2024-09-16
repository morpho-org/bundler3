// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseMorphoBundlerModule} from "../modules/BaseMorphoBundlerModule.sol";
import {IModularBundler} from "../interfaces/IModularBundler.sol";

event Initiator(address);

contract MorphoBundlerModuleMock is BaseMorphoBundlerModule {
    constructor(address bundler) BaseMorphoBundlerModule(bundler) {}

    function isProtected() external payable bundlerOnly {}

    function doRevert(string memory reason) external payable {
        revert(reason);
    }

    function emitInitiator() external payable {
        emit Initiator(initiator());
    }

    function callbackBundler(bytes calldata data) external payable bundlerOnly {
        IModularBundler(MORPHO_BUNDLER).multicallFromModule(data);
    }
}
