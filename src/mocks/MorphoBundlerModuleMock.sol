// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {MorphoBundlerModule} from "../modules/MorphoBundlerModule.sol";

contract MorphoBundlerModuleMock is MorphoBundlerModule {
    constructor(address bundler) MorphoBundlerModule(bundler) {}

    function _morphoBundlerModuleCall(address,bytes calldata) internal override {}
}
