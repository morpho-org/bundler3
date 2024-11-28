// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IERC20,
    ERC20Wrapper,
    ERC20
} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract ERC20WrapperMock is ERC20Wrapper {
    constructor(IERC20 token, string memory _name, string memory _symbol) ERC20Wrapper(token) ERC20(_name, _symbol) {}
}
