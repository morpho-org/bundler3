// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ModularBundler} from "../../src/ModularBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";

import "./helpers/LocalTest.sol";
import {MorphoBundlerModuleMock, Initiator} from "../../src/mocks/MorphoBundlerModuleMock.sol";

contract BaseMorphoBundlerModuleTest is LocalTest {
    MorphoBundlerModuleMock module;

    function setUp() public override {
        super.setUp();
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testGetInitiator(address initiator) public {
        vm.assume(initiator != address(0));

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(module));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testBubbleRevert(string memory revertReason) public {
        bundle.push(_moduleCall(address(module), abi.encodeCall(module.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }
}
