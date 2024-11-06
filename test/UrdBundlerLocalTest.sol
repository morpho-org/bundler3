// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor} from
    "../lib/universal-rewards-distributor/src/interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {ErrorsLib as UrdErrorsLib} from "../lib/universal-rewards-distributor/src/libraries/ErrorsLib.sol";

import {Merkle} from "../lib/murky/src/Merkle.sol";

import "./helpers/LocalTest.sol";

interface IUrdFactory {
    function createUrd(address, uint256, bytes32, bytes32, bytes32) external returns (address);
}

contract UrdBundlerLocalTest is LocalTest {
    IUrdFactory internal urdFactory;
    Merkle internal merkle;

    address internal distributor;

    function setUp() public override {
        super.setUp();

        urdFactory = IUrdFactory(deployCode("UrdFactory.sol", ""));
        vm.label(address(urdFactory), "UrdFactory");
        merkle = new Merkle();

        distributor = address(urdFactory.createUrd(OWNER, 0, bytes32(0), hex"", hex""));
    }

    function testClaimRewardsZeroAddressDistributor(uint256 claimable, address account) public {
        vm.assume(account != address(0));
        claimable = bound(claimable, MIN_AMOUNT, MAX_AMOUNT);

        bytes32[] memory proof;

        bundle.push(_urdClaim(address(0), account, address(loanToken), claimable, proof, false));

        vm.prank(USER);
        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testClaimRewardsZeroAddressAccount(uint256 claimable) public {
        claimable = bound(claimable, MIN_AMOUNT, MAX_AMOUNT);

        bytes32[] memory proof;

        bundle.push(_urdClaim(distributor, address(0), address(loanToken), claimable, proof, false));

        vm.prank(USER);
        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        bundler.multicall(bundle);
    }

    function testClaimRewardsBundlerAddress(uint256 claimable) public {
        claimable = bound(claimable, MIN_AMOUNT, MAX_AMOUNT);

        bytes32[] memory proof;

        bundle.push(_urdClaim(distributor, address(bundler), address(loanToken), claimable, proof, false));

        vm.prank(USER);
        vm.expectRevert(bytes(ErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(bundle);
    }

    function testClaimRewards(uint256 claimable, uint256 size) public {
        claimable = bound(claimable, 1 ether, 1000 ether);
        size = bound(size, 2, 20);

        bytes32[] memory tree = _setupRewards(claimable, size);

        loanToken.setBalance(distributor, claimable);
        collateralToken.setBalance(distributor, claimable);

        bytes32[] memory loanTokenProof = merkle.getProof(tree, 0);
        bytes32[] memory collateralTokenProof = merkle.getProof(tree, 1);

        bundle.push(_urdClaim(distributor, USER, address(loanToken), claimable, loanTokenProof, false));
        bundle.push(_urdClaim(distributor, USER, address(collateralToken), claimable, collateralTokenProof, false));
        bundle.push(_urdClaim(distributor, USER, address(loanToken), claimable, collateralTokenProof, true));
        bundle.push(_urdClaim(distributor, USER, address(collateralToken), claimable, loanTokenProof, true));

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(USER), claimable, "User's loan balance");
        assertEq(collateralToken.balanceOf(USER), claimable, "User's collateral balance");
    }

    function testClaimRewardsRevert(uint256 claimable, uint256 size) public {
        claimable = bound(claimable, 1 ether, 1000 ether);
        size = bound(size, 2, 20);

        bytes32[] memory tree = _setupRewards(claimable, size);

        loanToken.setBalance(distributor, claimable);
        collateralToken.setBalance(distributor, claimable);

        bytes32[] memory loanTokenProof = merkle.getProof(tree, 0);
        bytes32[] memory collateralTokenProof = merkle.getProof(tree, 1);

        bundle.push(_urdClaim(distributor, USER, address(loanToken), claimable, loanTokenProof, false));
        bundle.push(_urdClaim(distributor, USER, address(collateralToken), claimable, collateralTokenProof, false));
        bundle.push(_urdClaim(distributor, USER, address(loanToken), claimable, loanTokenProof, false));

        vm.prank(USER);
        vm.expectRevert(bytes(UrdErrorsLib.CLAIMABLE_TOO_LOW));
        bundler.multicall(bundle);
    }

    function _setupRewards(uint256 claimable, uint256 size) internal returns (bytes32[] memory tree) {
        tree = new bytes32[](size);

        tree[0] = keccak256(bytes.concat(keccak256(abi.encode(USER, address(loanToken), claimable))));
        tree[1] = keccak256(bytes.concat(keccak256(abi.encode(USER, address(collateralToken), claimable))));

        for (uint256 i = 2; i < size - 1; i += 2) {
            uint256 rank = i + 1;

            tree[i] = keccak256(
                bytes.concat(keccak256(abi.encode(vm.addr(rank), address(loanToken), uint256(claimable / rank))))
            );
            tree[i + 1] = keccak256(
                bytes.concat(keccak256(abi.encode(vm.addr(rank), address(collateralToken), uint256(claimable / rank))))
            );
        }

        bytes32 root = merkle.getRoot(tree);

        vm.prank(OWNER);
        IUniversalRewardsDistributor(distributor).setRoot(root, bytes32(0));
    }
}
