// SPDX-License-Identifier: GPL-2.0-or-later

// True when `approve` has been called.
persistent ghost bool approveCalled {
    init_state axiom approveCalled == false;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:ERC20Mock.approve(address, uint256).selector || selector == sig:ERC20PermitMock.permit(address, address, uint256, uint256, uint8, bytes32, bytes32).selector) {
       approveCalled = true;
    }
}

invariant allowancesNotDecreased()
    !approveCalled;
