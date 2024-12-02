// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";
import {IModuleMock, Initiator} from "../src/mocks/interfaces/IModuleMock.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract Empty {}

contract BundlerLocalTest is LocalTest {
    IModuleMock internal moduleMock;
    Call[] internal callbackBundle2;
    address internal empty;

    function setUp() public override {
        super.setUp();
        moduleMock = IModuleMock(payable(deployCode("ModuleMock.sol", abi.encode(bundler))));
        empty = address(new Empty());
    }

    function testBundlerZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        deployCode("BaseModuleMock.sol", abi.encode(address(0)));
    }

    function testMulticallEmpty() public {
        bundler.multicall(bundle);
    }

    function testAlreadyInitiated(address initiator) public {
        vm.assume(initiator != address(0));
        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundlerWithMulticall, ())));

        vm.expectRevert(ErrorsLib.AlreadyInitiated.selector);
        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testPassthroughValue(address initiator, uint128 value) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.isProtected, ()), value));

        vm.expectCall(address(moduleMock), value, bytes.concat(moduleMock.isProtected.selector));

        vm.deal(initiator, value);
        vm.prank(initiator);
        bundler.multicall{value: value}(bundle);
    }

    function testNestedCallbackAndCurrentModuleValue(address initiator) public {
        vm.assume(initiator != address(0));
        IModuleMock moduleMock2 = IModuleMock(payable(deployCode("ModuleMock.sol", abi.encode(bundler))));
        IModuleMock moduleMock3 = IModuleMock(payable(deployCode("ModuleMock.sol", abi.encode(bundler))));

        callbackBundle2.push(_call(moduleMock2, abi.encodeCall(moduleMock.isProtected, ())));

        callbackBundle.push(_call(moduleMock2, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle2))));

        callbackBundle.push(_call(moduleMock3, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle2))));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.callbackBundler, (callbackBundle))));

        vm.prank(initiator);

        vm.recordLogs();
        bundler.multicall(bundle);
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

    function testMulticallShouldSetTheRightInitiator(address initiator) public {
        vm.assume(initiator != address(0));

        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.emitInitiator, ())));

        vm.expectEmit(true, true, false, true, address(moduleMock));
        emit Initiator(initiator);

        vm.prank(initiator);
        bundler.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory revertReason) public {
        bundle.push(_call(moduleMock, abi.encodeCall(moduleMock.doRevert, (revertReason))));
        vm.expectRevert(bytes(revertReason));
        bundler.multicall(bundle);
    }

    function testProtectedFailure(address initiator, address module, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);
        vm.assume(caller != module);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setCurrentModule, (module)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));

        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        vm.prank(caller);
        bundler.multicallFromModule(new Call[](0));
    }

    function testProtectedSuccessAsModule(address initiator, address module) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != module);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setCurrentModule, (module)));

        vm.prank(module);
        bundler.multicallFromModule(new Call[](0));
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
