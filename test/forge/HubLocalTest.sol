// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../src/libraries/ErrorsLib.sol" as ErrorsLib;
import "../../src/libraries/ConstantsLib.sol" as ConstantsLib;

import "./helpers/LocalTest.sol";
import {BundlerMock, Initiator} from "../../src/mocks/BundlerMock.sol";
import {CURRENT_BUNDLER_SLOT} from "../../src/libraries/ConstantsLib.sol";
import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract HubLocalTest is LocalTest {
    BundlerMock bundlerMock;
    Call[] callbackBundle2;

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
        hub.multicall{value: value}(bundle);
    }

    function testNestedCallbackAndCurrentBundlerValue(address initiator) public {
        vm.assume(initiator != address(0));
        BundlerMock bundlerMock2 = new BundlerMock(address(hub));
        BundlerMock bundlerMock3 = new BundlerMock(address(hub));

        callbackBundle2.push(_call(bundlerMock2, abi.encodeCall(BundlerMock.isProtected, ())));

        callbackBundle.push(_call(bundlerMock2, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        callbackBundle.push(_call(bundlerMock3, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle2))));

        bundle.push(_call(bundlerMock, abi.encodeCall(BundlerMock.callbackHub, (callbackBundle))));

        vm.prank(initiator);

        vm.recordLogs();
        hub.multicall(bundle);
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
}
