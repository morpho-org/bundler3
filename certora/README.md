# Bundler3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for [Bundler3](../src/Bundler3.sol).

## Getting started

This project depends on several [Solidity](https://soliditylang.org/) versions which are required for running the verification.
The compiler binaries should be available at the paths:

- `solc-0.8.19` for the solidity compiler version `0.8.19`;
- `solc-0.8.28` for the solidity compiler version `0.8.28`.

To verify a specification, run the command `certoraRun Spec.conf` where `Spec.conf` is the configuration file of the matching CVL specification.
Configuration files are available in [`certora/confs`](confs).
Please ensure that `CERTORAKEY` is set up in your environment.

## Overview

The Bundler3 contract enables an EOA to call different endpoint contracts onchain as well as grouping several calls in a single bundle.
These calls may themselves reenter the Bundler3 contract.

### Approvals

The file [`EthereumGeneralAdapter1.sol`](../src/adapters/EthereumGeneralAdapter1.sol) is not checked since only trusted contracts are being approved in this adapter.

### Folders and file structure

The [`certora/specs`](specs) folder contains these files:

- [`Bundler3.spec`](specs/Bundler3.spec) checks Bundler3 entry points behave as expected;
- [`GeneralAdapter1Approvals.spec`](specs/GeneralAdapter1Approvals.spec), [`ParaswapApprovals.spec`](specs/ParaswapApprovals.spec),[`AaveV2Approvals.spec`](specs/AaveV2Approvals.spec), [`AaveV3Approvals.spec`](specs/AaveV3Approvals.spec),[`AaveV3OptimizerApprovals.spec`](specs/AaveV3OptimizerApprovals.spec), [`CompoundV2Approvals.spec`](specs/CompoundV2Approvals.spec), [`CompoundV3Approvals.spec`](specs/CompoundV3Approvals.spec)
 check that allowances to untrusted contracts are reset to zero in adapters;
- [`GeneralAdapter1Reverts.spec`](specs/GeneralAdapter1Reverts.spec) checks that state changes when adapter functions are called, or the execution reverts;
- [`MorphoZeroConditions.spec`](specs/MorphoZeroConditions.spec) checks that calls to Morpho with zero inputs that revert in Morpho make the adapter revert;
- [`OnlyBundler3.spec`](specs/OnlyBundler3.spec) checks that adapters' methods used during a bundle execution may only be called by the Bundler3 contract;
- [`ReenterCaller.spec`](specs/ReenterCaller.spec) checks that Bundler3 can be reentered only by the expected adapter functions;
- [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec) ensures that the transient storage is nullified on each entry-point call, this is checked with a separate configuration as it requires to disable sanity checks (because `reenter` cannot be an entry-point).

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/Makefile`](Makefile) is used to track and perform the required modifications on source files.
