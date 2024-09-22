// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ModularBundler} from "../../src/ModularBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";
import {UNSET_INITIATOR} from "../../src/libraries/ConstantsLib.sol";

import "./helpers/LocalTest.sol";
import {MorphoBundlerModuleMock, Initiator} from "../../src/mocks/MorphoBundlerModuleMock.sol";

contract BaseMorphoBundlerModuleTest is LocalTest {
    MorphoBundlerModuleMock module;

    function setUp() public override {
        super.setUp();
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testGetInitiator(address initiator) public {
        vm.assume(initiator != UNSET_INITIATOR);

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(module));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testProtectedSuccess() public {
        bundle.push(_moduleCall(address(module), abi.encodeCall(module.isProtected, ())));

        bundler.multicall(bundle);
    }

    function testProtectedFailure() public {
        bundle.push(_moduleCall(address(module), abi.encodeCall(module.isProtected, ())));

        BaseBundler otherBundler = new ChainAgnosticBundlerV2(address(morpho), address(new WETH()));
        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        otherBundler.multicall(bundle);
    }

    function testBubbleRevert(string memory revertReason) public {
        bundle.push(_moduleCall(address(module), abi.encodeCall(module.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }
}
