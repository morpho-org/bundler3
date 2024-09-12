// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseMorphoBundlerModule} from "../modules/BaseMorphoBundlerModule.sol";
import {IModularBundler} from "../interfaces/IModularBundler.sol";

contract MorphoBundlerModuleMock is BaseMorphoBundlerModule {

    constructor(address bundler) BaseMorphoBundlerModule(bundler) {}

    function _onMorphoBundlerCall(address, bytes calldata data) internal override {
        if (data.length == 0) {
            return;
        } else {
        } {
            IModularBundler(MORPHO_BUNDLER).multicallFromModule(data);
        }
    }
}
