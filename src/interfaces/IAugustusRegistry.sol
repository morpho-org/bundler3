// SPDX-License-Identifier: GPL-2.0-or-later
// Paraswap registry of valid Augustus contracts
// https://github.com/paraswap/augustus-v5/blob/d297477b8fc7be65c337b0cf2bc21f4f7f925b68/contracts/IAugustusRegistry.sol
pragma solidity >=0.5.0;

interface IAugustusRegistry {
    function isValidAugustus(address augustus) external view returns (bool);
}
