// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ModuleCallerBundler} from "../../src/ModuleCallerBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";

import "./helpers/LocalTest.sol";
import {MorphoBundlerModuleMock} from "../../src/mocks/MorphoBundlerModuleMock.sol";

contract BaseMorphoBundlerModuleTest is LocalTest {
    function testCheckCallerSuccess(address bundlerAddress) public {
        MorphoBundlerModuleMock mock = new MorphoBundlerModuleMock(bundlerAddress);

        bundle.push(abi.encodeCall(ModuleCallerBundler.callModule, (address(mock), hex"")));

        vm.prank(bundlerAddress);
        mock.morphoBundlerModuleCall(address(0), hex"");
    }

    function testCheckCallerFailure(address correctAddress, address wrongAddress) public {
        vm.assume(correctAddress != wrongAddress);
        MorphoBundlerModuleMock mock = new MorphoBundlerModuleMock(correctAddress);

        vm.prank(wrongAddress);
        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        mock.morphoBundlerModuleCall(address(0), hex"");
    }
}
