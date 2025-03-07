import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MockAugustus {
    address target;

    constructor(address _target) {
        target = _target;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        require(bytes4(msg.data[:4]) != IERC20.approve.selector);
        (bool success, bytes memory x) = address(target).call(data);
        require(success);
        return x;
    }
}
