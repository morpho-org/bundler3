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
        bundle.push(_call(address(adapterMock), abi.encodeCall(AdapterMock.callbackBundlerWithMulticall, ())));

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

        bundle.push(_call(address(adapterMock), abi.encodeCall(AdapterMock.isProtected, ()), value));

        vm.expectCall(address(adapterMock), value, bytes.concat(AdapterMock.isProtected.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle);
    }

    function testNestedCallbackAndLastUnreturnedCalleeValue(address initiator) public {
        vm.assume(initiator != address(0));
        AdapterMock adapterMock2 = new AdapterMock(address(bundler));
        AdapterMock adapterMock3 = new AdapterMock(address(bundler));

        callbackBundle2.push(_call(address(adapterMock2), abi.encodeCall(AdapterMock.isProtected, ())));

        callbackBundle.push(
            _call(address(adapterMock2), abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2)))
        );

        callbackBundle.push(
            _call(address(adapterMock3), abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle2)))
        );

        bundle.push(_call(address(adapterMock), abi.encodeCall(AdapterMock.callbackBundler, (callbackBundle))));

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle);
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

        bundle.push(_call(address(adapterMock), abi.encodeCall(AdapterMock.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(adapterMock));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory revertReason) public {
        bundle.push(_call(address(adapterMock), abi.encodeCall(AdapterMock.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }

    function testProtectedFailure(address initiator, address adapter, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);
        vm.assume(caller != adapter);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setLastUnreturnedCallee, (adapter)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(caller);
        bundler.reenter(new Call[](0));
    }

    function testProtectedSuccessAsAdapter(address initiator, address adapter) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != adapter);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setLastUnreturnedCallee, (adapter)));

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
