// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {AdapterMock, Initiator} from "./helpers/mocks/AdapterMock.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract Empty {}

contract ConcreteCoreAdapter is CoreAdapter {
    constructor(address bundler) CoreAdapter(bundler) {}
}

contract BundlerLocalTest is LocalTest {
    AdapterMock internal adapterMock;
    Call[] internal callbackBundle2;
    address internal empty;

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
        bundler.multicall{value: value}(bundle);
    }

    function testNestedCallbackAndReenterHashValue(address initiator) public {
        vm.assume(initiator != address(0));
        AdapterMock adapterMock2 = new AdapterMock(address(bundler));
        AdapterMock adapterMock3 = new AdapterMock(address(bundler));

        callbackBundle2.push(_call(adapterMock2, abi.encodeCall(AdapterMock.isProtected, ())));

        callbackBundle.push(
            _call(
                adapterMock2,
                abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2)),
                abi.encode(callbackBundle2)
            )
        );

        callbackBundle.push(
            _call(
                adapterMock3,
                abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2)),
                abi.encode(callbackBundle2)
            )
        );

        bundle.push(
            _call(
                adapterMock, abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle)), abi.encode(callbackBundle)
            )
        );

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 8);

        for (uint256 i = 0; i < entries.length; i++) {
            assertEq(entries[i].topics[0], keccak256("ReenterHash(bytes32)"));
        }

        bytes32 reenterHash1 = keccak256(bytes.concat(bytes20(address(adapterMock)), abi.encode(callbackBundle)));

        bytes32 reenterHash2 = keccak256(bytes.concat(bytes20(address(adapterMock2)), abi.encode(callbackBundle2)));

        bytes32 reenterHash3 = keccak256(bytes.concat(bytes20(address(adapterMock3)), abi.encode(callbackBundle2)));

        assertEq(entries[0].data, abi.encode(reenterHash1));
        assertEq(entries[1].data, abi.encode(reenterHash2));
        assertEq(entries[2].data, abi.encode(bytes32(0)));
        assertEq(entries[3].data, abi.encode(bytes32(0)));
        assertEq(entries[4].data, abi.encode(reenterHash3));
        assertEq(entries[5].data, abi.encode(bytes32(0)));
        assertEq(entries[6].data, abi.encode(bytes32(0)));
        assertEq(entries[7].data, abi.encode(bytes32(0)));
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

    function testProtectedFailure(address initiator, bytes32 badHash, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setReenterHash, (badHash)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));

        vm.expectRevert(ErrorsLib.IncorrectReenterHash.selector);
        vm.prank(caller);
        bundler.reenter(new Call[](0));
    }

    function testProtectedSuccessAsAdapter(address initiator, address adapter) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != adapter);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(
            address(bundler),
            abi.encodeCall(
                FunctionMocker.setReenterHash, (keccak256(bytes.concat(bytes20(adapter), abi.encode(new Call[](0)))))
            )
        );

        vm.prank(adapter);
        bundler.reenter(new Call[](0));
    }

    function testNotSkipRevert() public {
        Call memory failingCall = Call({to: empty, data: hex"", value: 0, skipRevert: false, reenterHash: bytes32(0)});

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
        Call memory failingCall = Call({to: empty, data: hex"", value: 0, skipRevert: true, reenterHash: bytes32(0)});

        bundle.push(failingCall);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testBadReenterHash(bytes32 badHash) public {
        Call[] memory calls = new Call[](0);
        bytes32 goodHash = keccak256(bytes.concat(bytes20(address(adapterMock)), abi.encode(calls)));
        vm.assume(badHash != goodHash);
        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.callbackBundler, (calls)), 0, false, badHash));

        vm.expectRevert(ErrorsLib.IncorrectReenterHash.selector);
        bundler.multicall(bundle);
    }

    function testGoodReenterHash(address from, uint256 size) public {
        size = bound(size, 0, 100);
        Call[] memory calls = new Call[](size);

        bytes32 goodHash = keccak256(bytes.concat(bytes20(from), abi.encode(calls)));

        bundle.push(
            _call(adapterMock, abi.encodeCall(AdapterMock.callbackBundlerFrom, (calls, from)), 0, false, goodHash)
        );

        bundler.multicall(bundle);
    }

    function testNestedBadReenterHash(bytes32 badHash) public {
        Call[] memory calls = new Call[](0);

        bytes32 goodHash = keccak256(bytes.concat(bytes20(address(adapterMock)), abi.encode(calls)));
        vm.assume(badHash != goodHash);
        callbackBundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.callbackBundler, (calls)), 0, false, badHash));
        bundle.push(
            _call(
                adapterMock, abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle)), abi.encode(callbackBundle)
            )
        );

        vm.expectRevert(ErrorsLib.IncorrectReenterHash.selector);
        bundler.multicall(bundle);
    }

    function testSequentialReenterFailsByDefault(uint256 size1, uint256 size2) public {
        size1 = bound(size1, 0, 10);
        size2 = bound(size2, 0, 10);
        Call[] memory calls1 = new Call[](size1);
        Call[] memory calls2 = new Call[](size2);
        bundle.push(
            _call(adapterMock, abi.encodeCall(AdapterMock.callbackBundlerTwice, (calls1, calls2)), abi.encode(calls1))
        );

        vm.expectRevert(ErrorsLib.IncorrectReenterHash.selector);
        bundler.multicall(bundle);
    }

    function testMissedReenterFailsByDefault(bytes32 _hash) public {
        bundle.push(_call(adapterMock, abi.encodeCall(AdapterMock.emitInitiator, ()), 0, false, _hash));
        vm.expectRevert(ErrorsLib.MissingExpectedReenter.selector);
        bundler.multicall(bundle);
    }
}
