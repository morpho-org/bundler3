// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @dev The typehash for approveManagerWithSig Authorization used for the EIP-712 signature.
bytes32 constant AUTHORIZATION_TYPEHASH =
    keccak256("Authorization(address delegator,address manager,bool isAllowed,uint256 nonce,uint256 deadline)");

/// @notice Contains the `v`, `r` and `s` parameters of an ECDSA signature.
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Authorization {
    address delegator;
    address manager;
    bool isAllowed;
    uint256 nonce;
    uint256 deadline;
}

interface IAaveV3Optimizer {
    error InvalidSignatory();

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        external
        returns (uint256 supplied);
    function supplyWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 maxIterations,
        uint256 deadline,
        Signature calldata signature
    ) external returns (uint256 supplied);
    function supplyCollateral(address underlying, uint256 amount, address onBehalf)
        external
        returns (uint256 supplied);
    function supplyCollateralWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 deadline,
        Signature calldata signature
    ) external returns (uint256 supplied);

    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256 borrowed);

    function repay(address underlying, uint256 amount, address onBehalf) external returns (uint256 repaid);
    function repayWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 deadline,
        Signature calldata signature
    ) external returns (uint256 repaid);

    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256 withdrawn);
    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        external
        returns (uint256 withdrawn);

    function approveManager(address manager, bool isAllowed) external;
    function approveManagerWithSig(
        address delegator,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 deadline,
        Signature calldata signature
    ) external;

    function liquidate(address underlyingBorrowed, address underlyingCollateral, address user, uint256 amount)
        external
        returns (uint256 repaid, uint256 seized);

    function claimRewards(address[] calldata assets, address onBehalf)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts);

    function borrowBalance(address underlying, address user) external view returns (uint256);
}
