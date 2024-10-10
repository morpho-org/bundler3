// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import "../../src/libraries/ConstantsLib.sol" as ConstantsLib;

import "./helpers/LocalTest.sol";
import {MorphoBundlerModuleMock} from "../../src/mocks/MorphoBundlerModuleMock.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";
import {CURRENT_MODULE_SLOT} from "../../src/libraries/ConstantsLib.sol";
import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract BaseBundlerLocalTest is LocalTest {
    MorphoBundlerModuleMock module;
    bytes[] callbackBundle2;

    function setUp() public override {
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testMulticallEmpty() public {
        bundler.multicall(bundle);
    }

    function testNestedMulticall() public {
        bundle.push(abi.encodeCall(BaseBundler.multicall, (callbackBundle)));

        vm.expectRevert(bytes(ErrorsLib.ALREADY_INITIATED));
        bundler.multicall(bundle);
    }

    function testInitiatorSlot() public pure {
        assertEq(ConstantsLib.INITIATOR_SLOT, keccak256("Morpho Bundler Initiator Slot"));
    }

    function testPassthroughValue(address initiator, uint128 value) public {
        vm.assume(initiator != address(0));

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.isProtected, ()), value));

        vm.expectCall(address(module), value, bytes.concat(IMorphoBundlerModule.onMorphoBundlerCallModule.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle);
    }

    function testCallbackDecode(address initiator, uint256 amount) public {
        vm.assume(initiator != address(0));
        address token = makeAddr("token mock");
        callbackBundle.push(abi.encodeCall(PermitBundler.permit, (token, amount, 0, 0, 0, 0, true)));

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle))));

        vm.etch(token, hex"01");
        vm.expectCall(token, abi.encodeCall(IERC20Permit.permit, (initiator, address(bundler), amount, 0, 0, 0, 0)));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testNestedCallbackAndCurrentModuleValue(address initiator) public {
        vm.assume(initiator != address(0));
        MorphoBundlerModuleMock module2 = new MorphoBundlerModuleMock(address(bundler));
        MorphoBundlerModuleMock module3 = new MorphoBundlerModuleMock(address(bundler));

        callbackBundle2.push(_moduleCall(address(module2), abi.encodeCall(module2.isProtected, ())));

        callbackBundle.push(
            _moduleCall(address(module2), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle2)))
        );

        callbackBundle.push(
            _moduleCall(address(module3), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle2)))
        );

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle))));

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 8);

        for (uint256 i = 0; i < entries.length; i++) {
            assertEq(entries[i].topics[0], keccak256("CurrentModule(address)"));
        }

        assertEq(entries[0].data, abi.encode(module));
        assertEq(entries[1].data, abi.encode(module2));
        assertEq(entries[2].data, abi.encode(module2));
        assertEq(entries[3].data, abi.encode(module2));
        assertEq(entries[4].data, abi.encode(module3));
        assertEq(entries[5].data, abi.encode(module2));
        assertEq(entries[6].data, abi.encode(module3));
        assertEq(entries[7].data, abi.encode(module));
    }

    function testCurrentModuleSlot() public pure {
        assertEq(CURRENT_MODULE_SLOT, keccak256("Morpho Bundler Current Module Slot"));
    }
}
