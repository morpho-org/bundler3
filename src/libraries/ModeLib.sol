// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

type Mode is bytes32;

library ModeLib {
    function to(Mode mode) internal pure returns (address) {
        return address(uint160(uint256(Mode.unwrap(mode))));
    }

    function skipRevert(Mode mode) internal pure returns (bool) {
        return uint256(Mode.unwrap(mode) >> 252) != 0;
    }

    function wrap(bool _skipRevert, address _to) internal pure returns (Mode) {
        bytes32 skipRevertBytes = bytes32(uint256(_skipRevert ? 1 : 0)) << 252;
        bytes32 toBytes = bytes32(uint256(uint160(_to)));
        return Mode.wrap(skipRevertBytes | toBytes);
    }
}
