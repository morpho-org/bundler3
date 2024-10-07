// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/LocalTest.sol";

contract BaseBundlerEnshrinedLocalTest is BaseBundler, LocalTest {
    function checkInitiator(address expectedInitiator) public payable protected {
        require(initiator() == expectedInitiator, "unexpected initiator");
    }

    function revertWith(string memory data) public payable protected {
        revert(data);
    }

    function testMulticallShouldSetTheRightInitiator(address caller) public {
        vm.assume(caller != address(0));

        bundle.push(abi.encodeCall(this.checkInitiator, (caller)));

        vm.prank(caller);
        this.multicall(bundle);
    }

    function testMulticallShouldPassRevertData(string memory data) public {
        bundle.push(abi.encodeCall(this.revertWith, (data)));

        vm.expectRevert(bytes(data));
        this.multicall(bundle);
    }
}
