import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MockAugustus {
    address target;

    constructor(address _target) {
        target = _target;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        require(bytes4(data[:4]) != IERC20.approve.selector);
        // Here we can't perform a delegate call as it would be summarized with the default case.
        // Nevertheless, since calls can be summarized appropiately, this can be used to show that `approve` is not
        // callable at all.
        (bool success, bytes memory x) = address(target).call(data);
        require(success);
        return x;
    }
}
