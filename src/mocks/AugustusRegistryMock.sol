// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAugustusRegistry} from "../interfaces/IAugustusRegistry.sol";

contract AugustusRegistryMock is IAugustusRegistry {
    mapping(address => bool) valids;

    function setValid(address account, bool isValid) external {
        valids[account] = isValid;
    }

    function isValidAugustus(address account) external view returns (bool) {
        return valids[account];
    }
}
