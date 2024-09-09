// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ModuleCallerBundler} from "../../src/ModuleCallerBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";

import "./helpers/LocalTest.sol";

contract ModuleCallerBundlerTest is LocalTest {
    function testPassthroughInitiator(address initiator) public {
        vm.mockCall(address(0), bytes.concat(IMorphoBundlerModule.morphoBundlerModuleCall.selector), hex"");

        bundle.push(abi.encodeCall(ModuleCallerBundler.callModule, (address(0), hex"")));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }
}
