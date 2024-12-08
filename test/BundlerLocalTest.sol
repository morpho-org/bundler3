// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {AdapterMock, Initiator} from "./helpers/mocks/AdapterMock.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CURRENT_BUNDLE_HASH_INDEX_SLOT, BUNDLE_HASH_0_SLOT} from "../src/libraries/ConstantsLib.sol";

contract Empty {}

contract ConcreteCoreAdapter is CoreAdapter {
    constructor(address bundler) CoreAdapter(bundler) {}
}

contract BundlerLocalTest is LocalTest {
    using BundlerLib for Bundler;

    AdapterMock internal adapterMock;
    Call[] internal callbackBundle2;
    address internal empty;

    bytes32[] internal callbackBundlesHashes;

    function setUp() public override {
        super.setUp();
        adapterMock = new AdapterMock(address(bundler));
        empty = address(new Empty());
    }

    function testBundlerZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new ConcreteCoreAdapter(address(0));
    }

    function testMulticallEmpty() public {
        bundler.multicall(bundle);
    }

    function testCurrentBundleHashIndexSlot() public pure {
        assertEq(CURRENT_BUNDLE_HASH_INDEX_SLOT, keccak256("Morpho Bundler Current Bundle Hash Index Slot"));
    }

    function testBundleHash0Slot() public pure {
        assertEq(BUNDLE_HASH_0_SLOT, keccak256("Morpho Bundler Bundle Hash 0 Slot"));
    }

    function testAlreadyInitiated(address initiator) public {
        vm.assume(initiator != address(0));
        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.callbackBundlerWithMulticall, ())));

        vm.expectRevert(ErrorsLib.AlreadyInitiated.selector);
        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testInitiatorReset(address initiator) public {
        vm.assume(initiator != address(0));

        vm.prank(initiator);
        bundler.multicall(bundle);

        assertEq(bundler.initiator(), address(0));

        // Test that it's possible to do a second multicall in the same tx.
        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testPassthroughValue(address initiator, uint128 value) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.isProtected, ()), value));

        vm.expectCall(address(adapterMock), value, bytes.concat(AdapterMock.isProtected.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle, new bytes32[](0));
    }

    function testNestedCallbackAndLastUnreturnedCalleeValue(address initiator) public {
        vm.assume(initiator != address(0));
        AdapterMock adapterMock2 = new AdapterMock(address(bundler));
        AdapterMock adapterMock3 = new AdapterMock(address(bundler));

        callbackBundle2.push(_call(adapterMock2, abi.encodeCall(AdapterMock.isProtected, ())));

        callbackBundle.push(_call(adapterMock2, abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2))));

        callbackBundle.push(_call(adapterMock3, abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle, callbackBundlesHashes);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 8);

        for (uint256 i = 0; i < entries.length; i++) {
            assertEq(entries[i].topics[0], keccak256("lastUnreturnedCallee(address)"));
        }

        assertEq(entries[0].data, abi.encode(adapterMock));
        assertEq(entries[1].data, abi.encode(adapterMock2));
        assertEq(entries[2].data, abi.encode(adapterMock2));
        assertEq(entries[3].data, abi.encode(adapterMock2));
        assertEq(entries[4].data, abi.encode(adapterMock3));
        assertEq(entries[5].data, abi.encode(adapterMock2));
        assertEq(entries[6].data, abi.encode(adapterMock3));
        assertEq(entries[7].data, abi.encode(adapterMock));
    }

    function testMulticallShouldSetTheRightInitiator(address initiator) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(adapterMock));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory revertReason) public {
        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }

    function testZeroHashes() public {
        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testSingleHash() public {
        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testWrongHash(bytes32 wrongHash) public {
        vm.assume(wrongHash != hex"");
        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(wrongHash);

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMissingHash() public {
        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle))));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testExtraHash(bytes32 _hash) public {
        vm.assume(_hash != hex"");
        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        callbackBundlesHashes.push(_hash);

        vm.expectRevert(ErrorsLib.MissingBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testNullHash(uint256 length, uint256 pos) public {
        length = bound(length, 1, 10);
        pos = bound(pos, 0, length - 1);
        bytes32 h1 = hex"01";
        bytes32 h0 = hex"";
        for (uint256 i = 0; i < length; i++) {
            callbackBundlesHashes.push(i == pos ? h0 : h1);
        }
        vm.expectRevert(ErrorsLib.NullHash.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashOK() public {
        callbackBundle2.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));

        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testMulticallMultiHashWrongOrder() public {
        callbackBundle2.push(_call(adapterMock, abi.encodeCall(adapterMock.emitInitiator, ())));

        callbackBundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(adapterMock, abi.encodeCall(adapterMock.callbackBundler, (callbackBundle))));

        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle2)));
        callbackBundlesHashes.push(keccak256(abi.encode(callbackBundle)));

        vm.expectRevert(ErrorsLib.InvalidBundle.selector);
        bundler.multicall(bundle, callbackBundlesHashes);
    }

    function testProtectedFailure(address initiator, address adapter, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);
        vm.assume(caller != adapter);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setLastUnreturnedCallee, (adapter)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(
            address(bundler),
            abi.encodeCall(FunctionMocker.setBundleHashAtIndex, (keccak256(abi.encode(new Call[](0))), 0))
        );

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(caller);
        bundler.reenter(new Call[](0));
    }

    function testProtectedSuccessAsAdapter(address initiator, address adapter) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != adapter);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setLastUnreturnedCallee, (adapter)));
        _delegatePrank(
            address(bundler),
            abi.encodeCall(FunctionMocker.setBundleHashAtIndex, (keccak256(abi.encode(new Call[](0))), 0))
        );

        vm.prank(adapter);
        bundler.reenter(new Call[](0));
    }

    function testNotSkipRevert() public {
        Call memory failingCall = Call({to: empty, data: hex"", value: 0, skipRevert: false});

        // Check that this produces a failing call.
        vm.prank(USER);
        (bool success,) = empty.call(hex"");
        assertFalse(success);

        bundle.push(failingCall);
        vm.prank(USER);
        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testSkipRevert() public {
        Call memory failingCall = Call({to: empty, data: hex"", value: 0, skipRevert: true});

        bundle.push(failingCall);
        vm.prank(USER);
        bundler.multicall(bundle);
    }
}
