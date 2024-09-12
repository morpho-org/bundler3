// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {IModuleCallerBundler} from "../../src/interfaces/IModuleCallerBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";
import {MorphoBundlerModuleMock} from "../../src/mocks/MorphoBundlerModuleMock.sol";
import {PermitBundler} from "../../src/PermitBundler.sol";

import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CURRENT_MODULE_SLOT} from "../../src/libraries/ConstantsLib.sol";
import "./helpers/LocalTest.sol";

contract ModuleCallerBundlerTest is LocalTest {

    IMorphoBundlerModule module;
    bytes[] callbackBundle2;

    function setUp() public override {
        super.setUp();
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testPassthroughInitiator(address initiator) public {
        bytes memory moduleData = hex"";
        bundle.push(abi.encodeCall(IModuleCallerBundler.callModule, (address(module), moduleData)));

        vm.expectCall(address(module),abi.encodeCall(IMorphoBundlerModule.morphoBundlerModuleCall,(initiator,moduleData)));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testCallbackDecode(address initiator, address token, uint amount) public {
        callbackBundle.push(abi.encodeCall(PermitBundler.permit,(token,amount,0,0,0,0,true)));

        bundle.push(abi.encodeCall(IModuleCallerBundler.callModule, (address(module), abi.encode(callbackBundle))));

        vm.etch(token,hex"01");
        vm.expectCall(token,abi.encodeCall(IERC20Permit.permit,(initiator,address(bundler),amount,0,0,0,0)));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testNestedCallback(address initiator) public {
        IMorphoBundlerModule module2 = new MorphoBundlerModuleMock(address(bundler));

        callbackBundle2.push(abi.encodeCall(IModuleCallerBundler.callModule,(address(module2),hex"")));

        // Run 2 toplevel callbacks to check that previousModule is correctly restored in ModuleCallerBundler.callModule.
        callbackBundle.push(abi.encodeCall(IModuleCallerBundler.callModule,(address(module2),abi.encode(callbackBundle2))));

        callbackBundle.push(abi.encodeCall(IModuleCallerBundler.callModule,(address(module2),abi.encode(callbackBundle2))));

        bundle.push(abi.encodeCall(IModuleCallerBundler.callModule,(address(module),abi.encode(callbackBundle))));

        vm.prank(initiator);
        bundler.multicall(bundle);

    }

    function testCurrentModuleSlot() pure public {
        assertEq(CURRENT_MODULE_SLOT, keccak256("Morpho Bundler Current Module Slot"));
    }
}
