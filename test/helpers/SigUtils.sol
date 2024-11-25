// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ICompoundV3} from "../../src/interfaces/ICompoundV3.sol";
import {Authorization} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IAllowanceTransfer} from "../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {
    Authorization as AaveV3OptimizerAuthorization,
    AUTHORIZATION_TYPEHASH as AAVE_V3_OPTIMIZER_AUTHORIZATION_TYPEHASH
} from "../../src/interfaces/IAaveV3Optimizer.sol";
import {
    Authorization as CompoundV3Authorization,
    DOMAIN_TYPEHASH as COMPOUND_V3_DOMAIN_TYPEHASH,
    AUTHORIZATION_TYPEHASH as COMPOUND_V3_AUTHORIZATION_TYPEHASH
} from "../../src/interfaces/ICompoundV3.sol";

import {PermitHash} from "../../lib/permit2/src/libraries/PermitHash.sol";
import {MessageHashUtils} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {AUTHORIZATION_TYPEHASH} from "../../lib/morpho-blue/src/libraries/ConstantsLib.sol";

bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

bytes32 constant DAI_PERMIT_TYPEHASH =
    keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");

struct DaiPermit {
    address holder;
    address spender;
    uint256 nonce;
    uint256 expiry;
    bool allowed;
}

library SigUtils {
    function toTypedDataHash(bytes32 domainSeparator, Permit memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.value, permit.nonce, permit.deadline)
            )
        );
    }

    function toTypedDataHash(bytes32 domainSeparator, Authorization memory authorization)
        internal
        pure
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(
                    AUTHORIZATION_TYPEHASH,
                    authorization.authorizer,
                    authorization.authorized,
                    authorization.isAuthorized,
                    authorization.nonce,
                    authorization.deadline
                )
            )
        );
    }

    function toTypedDataHash(bytes32 domainSeparator, IAllowanceTransfer.PermitSingle memory permitSingle)
        internal
        pure
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(domainSeparator, PermitHash.hash(permitSingle));
    }

    function toTypedDataHash(bytes32 domainSeparator, IAllowanceTransfer.PermitBatch memory permitBatch)
        internal
        pure
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(domainSeparator, PermitHash.hash(permitBatch));
    }

    function toTypedDataHash(bytes32 domainSeparator, AaveV3OptimizerAuthorization memory authorization)
        internal
        pure
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(
                    AAVE_V3_OPTIMIZER_AUTHORIZATION_TYPEHASH,
                    authorization.delegator,
                    authorization.manager,
                    authorization.isAllowed,
                    authorization.nonce,
                    authorization.deadline
                )
            )
        );
    }

    function toTypedDataHash(bytes32 domainSeparator, DaiPermit memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(
                    DAI_PERMIT_TYPEHASH, permit.holder, permit.spender, permit.nonce, permit.expiry, permit.allowed
                )
            )
        );
    }

    function toTypedDataHash(address instance, CompoundV3Authorization memory authorization)
        internal
        view
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(
            keccak256(
                abi.encode(
                    COMPOUND_V3_DOMAIN_TYPEHASH,
                    keccak256(bytes(ICompoundV3(instance).name())),
                    keccak256(bytes(ICompoundV3(instance).version())),
                    block.chainid,
                    instance
                )
            ),
            keccak256(
                abi.encode(
                    COMPOUND_V3_AUTHORIZATION_TYPEHASH,
                    authorization.owner,
                    authorization.manager,
                    authorization.isAllowed,
                    authorization.nonce,
                    authorization.expiry
                )
            )
        );
    }
}
