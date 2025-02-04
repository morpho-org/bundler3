// True when `approve` has been called.
persistent ghost bool approveCalled {
    init_state axiom approveCalled == false;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:ERC20Mock.approve(address, uint256).selector) {
       approveCalled = true;
    }
}

invariant allowancesNotChanged()
    !approveCalled;
