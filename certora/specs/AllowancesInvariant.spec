// True when `approve` has been called.
persistent ghost bool approveCalled {
    init_state axiom approveCalled == false;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
     // Hardcoding the approve(addres, uint256) ABI selector with 0x095ea7b3 avoids an error due to the method not being found.
    if (selector == 0x095ea7b3) {
       approveCalled = true;
    }
}

invariant allowancesNotChanged()
    !approveCalled;
