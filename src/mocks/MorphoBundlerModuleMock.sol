// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseMorphoBundlerModule} from "../modules/BaseMorphoBundlerModule.sol";

contract MorphoBundlerModuleMock is BaseMorphoBundlerModule {
    constructor(address bundler) BaseMorphoBundlerModule(bundler) {}

    function _morphoBundlerModuleCall(address, bytes calldata) internal override {}
}
