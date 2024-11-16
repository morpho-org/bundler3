// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import "../src/libraries/ConstantsLib.sol" as ConstantsLib;

import "./helpers/LocalTest.sol";
import {ModuleMock, Initiator} from "../src/mocks/ModuleMock.sol";
import {CURRENT_MODULE_SLOT} from "../src/libraries/ConstantsLib.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract BundlerLocalTest is LocalTest {
    using BundlerLib for Bundler;

    ModuleMock moduleMock;
    Call[] callbackBundle2;

    bytes32[] internal callbackBundlesHashes;

    function setUp() public override {
        super.setUp();
        moduleMock = new ModuleMock(address(bundler));
    }

    function testBundlerZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new BaseModule(address(0));
    }

    function testMulticallEmpty() public {
        bundler.multicall(bundle);
    }

    function testInitiatorSlot() public pure {
        assertEq(ConstantsLib.INITIATOR_SLOT, keccak256("Morpho Bundler Initiator Slot"));
    }

    function testCurrentBundleHashIndexSlot() public pure {
        assertEq(
            ConstantsLib.CURRENT_BUNDLE_HASH_INDEX_SLOT, keccak256("Morpho Bundler Current Bundle Hash Index Slot")
        );
    }

    function testBundleHash0Slot() public pure {
        assertEq(ConstantsLib.BUNDLE_HASH_0_SLOT, keccak256("Morpho Bundler Bundle Hash 0 Slot"));
    }

    function testAlreadyInitiated(address initiator) public {
        vm.assume(initiator != address(0));
        bundle.push(_call(moduleMock, abi.encodeCall(ModuleMock.callbackBundlerWithMulticall, ())));

        vm.expectRevert(ErrorsLib.AlreadyInitiated.selector);
        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testPassthroughValue(address initiator, uint128 value) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(moduleMock, abi.encodeCall(ModuleMock.isProtected, ()), value));

        vm.expectCall(address(moduleMock), value, bytes.concat(ModuleMock.isProtected.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle, new bytes32[](0));
    }

    function testNestedCallbackAndCurrentModuleValue(address initiator) public {
        vm.assume(initiator != address(0));
        ModuleMock moduleMock2 = new ModuleMock(address(bundler));
        ModuleMock moduleMock3 = new ModuleMock(address(bundler));

        callbackBundle2.push(_call(moduleMock2, abi.encodeCall(ModuleMock.isProtected, ())));

        callbackBundle.push(_call(moduleMock2, abi.encodeCall(ModuleMock.callbackBundler, (callbackBundle2))));

        callbackBundle.push(_call(moduleMock3, abi.encodeCall(ModuleMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(moduleMock, abi.encodeCall(ModuleMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle, callbackBundlesHashes);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 8);

        for (uint256 i = 0; i < entries.length; i++) {
            assertEq(entries[i].topics[0], keccak256("CurrentModule(address)"));
        }

        assertEq(entries[0].data, abi.encode(moduleMock));
        assertEq(entries[1].data, abi.encode(moduleMock2));
        assertEq(entries[2].data, abi.encode(moduleMock2));
        assertEq(entries[3].data, abi.encode(moduleMock2));
        assertEq(entries[4].data, abi.encode(moduleMock3));
        assertEq(entries[5].data, abi.encode(moduleMock2));
        assertEq(entries[6].data, abi.encode(moduleMock3));
        assertEq(entries[7].data, abi.encode(moduleMock));
    }

    function testCurrentModuleSlot() public pure {
        assertEq(CURRENT_MODULE_SLOT, keccak256("Morpho Bundler Current Module Slot"));
    }

    function testMulticallShouldSetTheRightInitiator(address initiator) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(moduleMock, abi.encodeCall(ModuleMock.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(moduleMock));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory revertReason) public {
        bundle.push(_call(moduleMock, abi.encodeCall(ModuleMock.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }

    function testZeroHashes() public {
        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testSingleHash() public {
        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testWrongHash(bytes32 wrongHash) public {
        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(wrongHash);

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMissingHash() public {
        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testExtraHash(bytes32 _hash) public {
        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        callbackBundlesHashes.push(_hash);

        vm.expectRevert(ErrorsLib.MissingBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashOK() public {
        callbackBundle2.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashWrongOrder() public {
        callbackBundle2.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        callbackBundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }
}
