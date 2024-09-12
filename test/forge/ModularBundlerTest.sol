// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {IModularBundler} from "../../src/interfaces/IModularBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";
import {MorphoBundlerModuleMock} from "../../src/mocks/MorphoBundlerModuleMock.sol";
import {PermitBundler} from "../../src/PermitBundler.sol";

import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CURRENT_MODULE_SLOT} from "../../src/libraries/ConstantsLib.sol";
import "./helpers/LocalTest.sol";

contract ModularBundlerTest is LocalTest {

    IMorphoBundlerModule module;
    bytes[] callbackBundle2;

    function setUp() public override {
        super.setUp();
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testPassthroughInitiator(address initiator) public {
        bundle.push(abi.encodeCall(IModularBundler.callModule, (address(module), hex"",0)));

        vm.expectCall(address(module),0,abi.encodeCall(IMorphoBundlerModule.onMorphoBundlerCall,(initiator,hex"")));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testPassthroughValue(uint128 value) public {
        address initiator = makeAddr("initiator");
        bundle.push(abi.encodeCall(IModularBundler.callModule, (address(module), hex"",value)));

        vm.expectCall(address(module),value,abi.encodeCall(IMorphoBundlerModule.onMorphoBundlerCall,(initiator,hex"")));

        vm.deal(initiator,value);
        vm.prank(initiator);
        bundler.multicall{value:value}(bundle);
    }

    function testCallbackDecode(address initiator, uint amount) public {
        address token = makeAddr("token mock");
        callbackBundle.push(abi.encodeCall(PermitBundler.permit,(token,amount,0,0,0,0,true)));

        bundle.push(abi.encodeCall(IModularBundler.callModule, (address(module),  abi.encode(callbackBundle),0)));

        vm.etch(token,hex"01");
        vm.expectCall(token,abi.encodeCall(IERC20Permit.permit,(initiator,address(bundler),amount,0,0,0,0)));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testNestedCallback(address initiator) public {
        IMorphoBundlerModule module2 = new MorphoBundlerModuleMock(address(bundler));

        callbackBundle2.push(abi.encodeCall(IModularBundler.callModule,(address(module2),hex"",0)));

        // Run 2 toplevel callbacks to check that previousModule is correctly restored in ModularBundler.callModule.
        callbackBundle.push(abi.encodeCall(IModularBundler.callModule,(address(module2),abi.encode(callbackBundle2),0)));

        callbackBundle.push(abi.encodeCall(IModularBundler.callModule,(address(module2),abi.encode(callbackBundle2),0)));

        bundle.push(abi.encodeCall(IModularBundler.callModule,(address(module),abi.encode(callbackBundle),0)));

        vm.prank(initiator);
        bundler.multicall(bundle);

    }

    function testCurrentModuleSlot() pure public {
        assertEq(CURRENT_MODULE_SLOT, keccak256("Morpho Bundler Current Module Slot"));
    }
}
