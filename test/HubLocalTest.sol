// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import "../src/libraries/ConstantsLib.sol" as ConstantsLib;

import "./helpers/LocalTest.sol";
import {BundlerMock, Initiator} from "../src/mocks/BundlerMock.sol";
import {CURRENT_BUNDLER_SLOT} from "../src/libraries/ConstantsLib.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract HubLocalTest is LocalTest {
    using HubLib for Hub;

    BundlerMock bundlerMock;
    Call[] callbackBundle2;

    bytes32[] internal callbackBundlesHashes;

    function setUp() public override {
        super.setUp();
        bundlerMock = new BundlerMock(address(hub));
    }

    function testHubZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new BaseBundler(address(0));
    }

    function testMulticallEmpty() public {
        hub.multicall(bundle);
    }

    function testInitiatorSlot() public pure {
        assertEq(ConstantsLib.INITIATOR_SLOT, keccak256("Morpho Bundler Hub Initiator Slot"));
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
        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.callbackHubWithMulticall, ())));

        vm.expectRevert(ErrorsLib.AlreadyInitiated.selector);
        vm.prank(initiator);
        hub.multicall(bundle);
    }

    function testPassthroughValue(address initiator, uint128 value) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.isProtected, ()), value));

        vm.expectCall(address(bundlerMock), value, bytes.concat(BundlerMock.isProtected.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        hub.multicall{value: value}(bundle, new bytes32[](0));
    }

    function testNestedCallbackAndCurrentBundlerValue(address initiator) public {
        vm.assume(initiator != address(0));
        BundlerMock bundlerMock2 = new BundlerMock(address(hub));
        BundlerMock bundlerMock3 = new BundlerMock(address(hub));

        callbackBundle2.push(_call(bundlerMock2, abi.encodeCall(BundlerMock.isProtected, ())));

        callbackBundle.push(_call(bundlerMock2, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        callbackBundle.push(_call(bundlerMock3, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        vm.prank(initiator);
        vm.recordLogs();
        hub.multicall(bundle, callbackBundlesHashes);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 8);

        for (uint256 i = 0; i < entries.length; i++) {
            assertEq(entries[i].topics[0], keccak256("CurrentBundler(address)"));
        }

        assertEq(entries[0].data, abi.encode(bundlerMock));
        assertEq(entries[1].data, abi.encode(bundlerMock2));
        assertEq(entries[2].data, abi.encode(bundlerMock2));
        assertEq(entries[3].data, abi.encode(bundlerMock2));
        assertEq(entries[4].data, abi.encode(bundlerMock3));
        assertEq(entries[5].data, abi.encode(bundlerMock2));
        assertEq(entries[6].data, abi.encode(bundlerMock3));
        assertEq(entries[7].data, abi.encode(bundlerMock));
    }

    function testCurrentBundlerSlot() public pure {
        assertEq(CURRENT_BUNDLER_SLOT, keccak256("Morpho Bundler Current Bundler Slot"));
    }

    function testMulticallShouldSetTheRightInitiator(address initiator) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(bundlerMock));
        emit Initiator(initiator);

        vm.prank(initiator);
        hub.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory revertReason) public {
        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        hub.multicall(bundle);
    }

    function testZeroHashes() public {
        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.emitInitiator, ())));
        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testSingleHash() public {
        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.callbackHub, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testWrongHash(bytes32 wrongHash) public {
        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.callbackHub, (callbackBundle))));

        callbackBundlesHashes.push(wrongHash);

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testMissingHash() public {
        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.callbackHub, (callbackBundle))));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testExtraHash(bytes32 _hash) public {
        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        callbackBundlesHashes.push(_hash);

        vm.expectRevert(ErrorsLib.MissingBundle.selector);
        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashOK() public {
        callbackBundle2.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.callbackHub, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        hub.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashWrongOrder() public {
        callbackBundle2.push(_call(bundlerMock, abi.encodeCall(BundlerMock.emitInitiator, ())));

        callbackBundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        bundle.push(_call(bundlerMock, abi.encodeCall(bundlerMock.callbackHub, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        hub.multicall(bundle, callbackBundlesHashes);
    }
}
