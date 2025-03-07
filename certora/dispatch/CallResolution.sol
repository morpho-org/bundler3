import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract CallResolution {
    address target;

    constructor(address _target) {
        target = _target;
    }

    function doUnresolvedCall(bytes calldata data) external returns (bytes memory) {
        // Calls to approve are not allowed, summarization aren not expected to be resolvable.
        require(bytes4(msg.data[:4]) != IERC20.approve.selector);
        (bool success, bytes memory x) = address(target).call(data);
        require(success);
        return x;
    }
}
