// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IERC20,
    ERC20Wrapper,
    ERC20
} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract ERC20PermissionedWrapperMock is ERC20Wrapper {
    mapping (address => bool) public whitelist;

    constructor(IERC20 token, string memory _name, string memory _symbol) ERC20Wrapper(token) ERC20(_name, _symbol) {}

    function _update(address from, address to, uint value) internal virtual override {
        if (to != address(0)) {
            if (from != address(0)) {
                if (!whitelist[from]) {
                    revert("ERC20WrapperMock: non-whitelisted from address");
                }
            }
            if (!whitelist[to]) {
                revert("ERC20WrapperMock: non-whitelisted to address");
            }
        }
        super._update(from,to,value);
    }

    function updateWhitelist(address account, bool isWhitelisted) public {
        whitelist[account] = isWhitelisted;
    }

}
