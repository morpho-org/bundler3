// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {IModularBundler} from "../../src/interfaces/IModularBundler.sol";
import {IMorphoBundlerModule} from "../../src/interfaces/IMorphoBundlerModule.sol";
import {MorphoBundlerModuleMock} from "../../src/mocks/MorphoBundlerModuleMock.sol";
import {PermitBundler} from "../../src/PermitBundler.sol";

import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CURRENT_MODULE_SLOT} from "../../src/libraries/ConstantsLib.sol";
import {UNSET_INITIATOR} from "../../src/libraries/ConstantsLib.sol";
import "./helpers/LocalTest.sol";

contract ModularBundlerTest is LocalTest {
    MorphoBundlerModuleMock module;
    bytes[] callbackBundle2;

    function setUp() public override {
        super.setUp();
        module = new MorphoBundlerModuleMock(address(bundler));
    }

    function testPassthroughValue(uint128 value) public {
        address initiator = makeAddr("initiator");

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.isProtected, ()), value));

        vm.expectCall(address(module), value, bytes.concat(IMorphoBundlerModule.onMorphoBundlerCall.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle);
    }

    function testCallbackDecode(address initiator, uint256 amount) public {
        vm.assume(initiator != UNSET_INITIATOR);
        address token = makeAddr("token mock");
        callbackBundle.push(abi.encodeCall(PermitBundler.permit, (token, amount, 0, 0, 0, 0, true)));

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle))));

        vm.etch(token, hex"01");
        vm.expectCall(token, abi.encodeCall(IERC20Permit.permit, (initiator, address(bundler), amount, 0, 0, 0, 0)));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testNestedCallback(address initiator) public {
        vm.assume(initiator != UNSET_INITIATOR);
        MorphoBundlerModuleMock module2 = new MorphoBundlerModuleMock(address(bundler));

        callbackBundle2.push(_moduleCall(address(module2), abi.encodeCall(module2.isProtected, ())));

        // Run 2 toplevel callbacks to check that previousModule is correctly restored in ModularBundler.callModule.
        callbackBundle.push(
            _moduleCall(address(module2), abi.encodeCall(module2.callbackBundler, abi.encode(callbackBundle2)))
        );

        callbackBundle.push(
            _moduleCall(address(module2), abi.encodeCall(module2.callbackBundler, abi.encode(callbackBundle2)))
        );

        bundle.push(_moduleCall(address(module), abi.encodeCall(module.callbackBundler, abi.encode(callbackBundle))));

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testCurrentModuleSlot() public {
        assertEq(CURRENT_MODULE_SLOT, keccak256("Morpho Bundler Current Module Slot"));
    }
}
