// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {BaseModule} from "../BaseModule.sol";

contract BaseModuleMock is BaseModule {
    constructor(address bundler) BaseModule(bundler) {}
}
