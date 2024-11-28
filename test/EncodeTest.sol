// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import {ModeLib, Mode} from "../src/libraries/ModeLib.sol";
import {Call} from "../src/interfaces/IBundler.sol";

contract EncodeTest is Test {
    using ModeLib for Mode;

    function testWrapUnwrap(bool skipRevert, address to) public pure {
        Mode mode = ModeLib.wrap(skipRevert, to);
        assertEq(mode.to(), to);
        assertEq(mode.skipRevert(), skipRevert);
    }

    function testEncodeLength(Call memory _call) public pure {
        // Number of bytes:
        // - selector is 4 bytes
        // - struct offset is 32 bytes
        // - mode is 32 bytes
        // - value is 32 bytes
        // - data offset is 32 bytes
        // - data length is 32 bytes
        // - data is fits in data.length rounded up on 32 bytes words
        assertEq(abi.encodeWithSelector(0xaaaaaaaa, _call).length, 4 + 5 * 32 + (_call.data.length + 31) / 32 * 32);
    }
}
