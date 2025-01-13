# Bundler V3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for the [Bundler](../src/Bunlder.sol) V3.

## Getting started

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

This is checked in [`Bundler.spec`](specs/Bundler.spec) and [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec).

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Bundler.spec`](specs/Bundler.spec) checks that Bundler entry points behave as expected;
- [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec) ensures that the transient storage is nullified on each entry-point call, this is checked with a separate configuration as it requires to disable sanity checks (because `reenter` cannot be an entry-point).

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/Makefile`](Makefile) is used to track and perform the required modifications on source files.
