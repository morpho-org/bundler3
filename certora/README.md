# Bundler V3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for the [Bundler](../src/Bunlder.sol) V3.

## Getting started

The verification is performed on modified source files, which can generated with the command:

```
make -C certora munged
```

This project depends on several [Solidity](https://soliditylang.org/) versions which are required for running the verification.
The compiler binaries should be available at the paths:

- `solc-0.8.19` for the solidity compiler version `0.8.19`;
- `solc-0.8.28` for the solidity compiler version `0.8.28`.

To verify a specification, run the command `certoraRun Spec.conf` where `Spec.conf` is the configuration file of the matching CVL specification.
Configuration files are available in [`certora/confs`](confs).
Please ensure that `CERTORAKEY` is set up in your environment.

## Overview

The Bundler contract enables an EOA to call different endpoint contracts onchain as well as grouping several calls in a single bundle.
These calls may themselves reenter the bundler.

### Bundler

This is checked in [`Bundler.spec`](specs/Bundler.spec).

### Approvals

This is checked in the hereby listed files:
- [`GeneralAdapter1Approvals.spec`](specs/GeneralAdapter1Approvals.spec);
- [`ParaswapApprovals.spec`](specs/ParaswapApprovals.spec);
- [`AaveV2Approvals.spec`](specs/AaveV2Approvals.spec);
- [`AaveV3Approvals.spec`](specs/AaveV3Approvals.spec);
- [`AaveV3OptimizerApprovals.spec`](specs/AaveV3OptimizerApprovals.spec);
- [`CompoundV2Approvals.spec`](specs/CompoundV2Approvals.spec);
- [`CompoundV3Approvals.spec`](specs/CompoundV3Approvals.spec).

Note: the file [`EthereumGeneralAdapter1.sol`](../src/adapters/EthereumGeneralAdapter1.sol) is not checked since only trusted contracts are being approved in this adapter.

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains these files:

- [`Bundler.spec`](specs/Bundler.spec) checks that Bundler entry points behave as expected;
- [`GeneralAdapter1Approvals.spec`](specs/GeneralAdapter1Approvals.spec), [`ParaswapApprovals.spec`](specs/ParaswapApprovals.spec),[`AaveV2Approvals.spec`](specs/AaveV2Approvals.spec), [`AaveV3Approvals.spec`](specs/AaveV3Approvals.spec),[`AaveV3OptimizerApprovals.spec`](specs/AaveV3OptimizerApprovals.spec), [`CompoundV2Approvals.spec`](specs/CompoundV2Approvals.spec), [`CompoundV3Approvals.spec`](specs/CompoundV3Approvals.spec)
 check that allowances to untrusted contracts are reset to zero in adapters.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/Makefile`](Makefile) is used to track and perform the required modifications on source files.
