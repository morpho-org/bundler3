// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBundler3, Call} from "./interfaces/IBundler3.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Enables batching multiple calls in a single one.
/// @notice Transiently stores the initiator of the multicall.
/// @notice Can be reentered by the last unreturned callee with known data.
/// @dev Anybody can do arbitrary calls with this contract, so it should not be approved/authorized anywhere.
contract Bundler3 is IBundler3 {
    /* TRANSIENT STORAGE */

    /// @notice The initiator of the multicall transaction.
    //address public transient initiator;
    function setInitiator(address _initiator) internal {
        assembly ("memory-safe") {
            // keccak256("Bundler3 Initiator Slot")
            tstore(0xd7d251e7c361c14039189f95fe00c18c4a6f62d97ee0d19ed27711cc23c80309, _initiator)
        }
    }

    function initiator() public view returns (address _initiator) {
        assembly ("memory-safe") {
            // keccak256("Bundler3 Initiator Slot")
            _initiator := tload(0xd7d251e7c361c14039189f95fe00c18c4a6f62d97ee0d19ed27711cc23c80309)
        }
    }

    /// @notice Hash of the concatenation of the sender and the hash of the calldata of the next call to `reenter`.
    //bytes32 public transient reenterHash;

    function setReenterHash(bytes32 _reenterHash) internal {
        assembly ("memory-safe") {
            // keccak256("Bundler3 Reenter Hash Slot")
            tstore(0x4aceee294ca47ef8bbab20072b9948fa509670620bc2438df44f99e571938b6d, _reenterHash)
        }
    }

    function reenterHash() public view returns (bytes32 _reenterHash) {
        assembly ("memory-safe") {
            // keccak256("Bundler3 Reenter Hash Slot")
            _reenterHash := tload(0x4aceee294ca47ef8bbab20072b9948fa509670620bc2438df44f99e571938b6d)
        }
    }

    /* EXTERNAL */

    /// @notice Executes a sequence of calls.
    /// @dev Locks the initiator so that the sender can be identified by other contracts.
    /// @param bundle The ordered array of calldata to execute.
    function multicall(Call[] calldata bundle) external payable {
        require(initiator() == address(0), ErrorsLib.AlreadyInitiated());

        setInitiator(msg.sender);

        _multicall(bundle);

        setInitiator(address(0));
    }

    /// @notice Executes a sequence of calls.
    /// @dev Useful during callbacks.
    /// @dev Can only be called by the last unreturned callee with known data.
    /// @param bundle The ordered array of calldata to execute.
    function reenter(Call[] calldata bundle) external {
        require(
            reenterHash() == keccak256(bytes.concat(bytes20(msg.sender), keccak256(msg.data[4:]))),
            ErrorsLib.IncorrectReenterHash()
        );
        _multicall(bundle);
        // After _multicall the value of reenterHash is bytes32(0).
    }

    /* INTERNAL */

    /// @notice Executes a sequence of calls.
    function _multicall(Call[] calldata bundle) internal {
        require(bundle.length > 0, ErrorsLib.EmptyBundle());

        for (uint256 i; i < bundle.length; ++i) {
            address to = bundle[i].to;
            bytes32 callbackHash = bundle[i].callbackHash;
            if (callbackHash == bytes32(0)) setReenterHash(bytes32(0));
            else setReenterHash(keccak256(bytes.concat(bytes20(to), callbackHash)));

            (bool success, bytes memory returnData) = to.call{value: bundle[i].value}(bundle[i].data);
            if (!bundle[i].skipRevert && !success) UtilsLib.lowLevelRevert(returnData);

            require(reenterHash() == bytes32(0), ErrorsLib.MissingExpectedReenter());
        }
    }
}
