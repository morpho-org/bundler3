// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import {BytesLib} from "../src/libraries/BytesLib.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract BytesLibTest is Test {
    function testGetInvalidOffset(bytes memory data, uint256 offset) public {
        vm.assume(data.length >= 32);
        vm.assume(offset > data.length - 32);
        vm.expectRevert(ErrorsLib.InvalidOffset.selector);
        BytesLib.get(data, offset);
    }

    function testSetInvalidOffset(bytes memory data, uint256 offset) public {
        vm.assume(data.length >= 32);
        vm.assume(offset > data.length - 32);
        vm.expectRevert(ErrorsLib.InvalidOffset.selector);
        BytesLib.set(data, offset, 0);
    }
}
