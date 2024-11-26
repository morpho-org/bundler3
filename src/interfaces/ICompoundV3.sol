// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

bytes32 constant DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

bytes32 constant AUTHORIZATION_TYPEHASH =
    keccak256("Authorization(address owner,address manager,bool isAllowed,uint256 nonce,uint256 expiry)");

struct Authorization {
    address owner;
    address manager;
    bool isAllowed;
    uint256 nonce;
    uint256 expiry;
}

struct UserCollateral {
    uint128 balance;
    uint128 _reserved;
}

interface ICompoundV3 {
    error BadSignatory();

    function name() external view returns (string memory);

    function version() external view returns (string memory);

    function baseToken() external view returns (address);

    function userCollateral(address account, address asset) external view returns (UserCollateral memory);

    function balanceOf(address account) external view returns (uint256);

    function borrowBalanceOf(address account) external view returns (uint256);

    function supply(address asset, uint256 amount) external;

    function supplyTo(address dst, address asset, uint256 amount) external;

    function supplyFrom(address from, address dst, address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function withdrawFrom(address src, address to, address asset, uint256 amount) external;

    function allow(address manager, bool isAllowed_) external;

    function allowBySig(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
