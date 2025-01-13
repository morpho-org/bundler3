# Bundler3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for [Bundler3](../src/Bundler3.sol).

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

The Bundler3 contract enables an EOA to call different endpoint contracts onchain as well as grouping several calls in a single bundle.
These calls may themselves reenter Bundler3.

### Bundler3

This is checked in [`Bundler3.spec`](specs/Bundler3.spec) and [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec).

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Bundler3.spec`](specs/Bundler3.spec) checks that Bundler3 entry points behave as expected;
- [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec) ensures that the transient storage is nullified on each entry-point call, this is checked with a separate configuration as it requires to disable sanity checks (because `reenter` cannot be an entry-point).

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/Makefile`](Makefile) is used to track and perform the required modifications on source files.
