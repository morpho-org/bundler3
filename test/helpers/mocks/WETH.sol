// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Address} from "../../../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {ERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice Minimalist and modern Wrapped Ether implementation, uses OZ contracts.
/// @author Adapted from Solmate's WETH (https://github.com/transmissions11/solmate/blob/main/src/tokens/WETH.sol)
contract WETH is ERC20("Wrapped Ether", "WETH") {
    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    function deposit() public payable virtual {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public virtual {
        _burn(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);

        Address.sendValue(payable(msg.sender), amount);
    }

    receive() external payable virtual {
        deposit();
    }
}
