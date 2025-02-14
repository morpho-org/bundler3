// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import {BytesLib} from "../src/libraries/BytesLib.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract BytesLibTest is Test {
    /// forge-config: default.allow_internal_expect_revert = true
    function testGetInvalidOffset(bytes memory data, uint256 offset) public {
        vm.assume(data.length >= 32);
        vm.assume(offset > data.length - 32);
        vm.expectRevert(ErrorsLib.InvalidOffset.selector);
        BytesLib.get(data, offset);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testSetInvalidOffset(bytes memory data, uint256 offset) public {
        vm.assume(data.length >= 32);
        vm.assume(offset > data.length - 32);
        vm.expectRevert(ErrorsLib.InvalidOffset.selector);
        BytesLib.set(data, offset, 0);
    }

    function testGetValidOffset(uint256 length, uint256 offset, uint256 value) public pure {
        length = bound(length, 32, type(uint16).max);
        offset = bound(offset, 0, length - 32);
        bytes memory data = bytes.concat(new bytes(offset), bytes32(value), new bytes(length - offset - 32));
        uint256 retrievedValue = BytesLib.get(data, offset);
        assertEq(value, retrievedValue);
    }

    function testSetValidOffset(uint256 length, uint256 offset, uint256 value) public pure {
        length = bound(length, 32, type(uint16).max);
        offset = bound(offset, 0, length - 32);
        bytes memory expectedBytes = bytes.concat(new bytes(offset), bytes32(value), new bytes(length - offset - 32));
        bytes memory actualBytes = new bytes(length);
        BytesLib.set(actualBytes, offset, value);
        assertEq(expectedBytes, actualBytes);
    }
}
