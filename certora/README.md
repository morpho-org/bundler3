# Bundlers formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for the following bundler contracts:

- [AaveV2MigrationBundlerV2](../src/migration/AaveV2MigrationBundlerV2.sol)
- [AaveV3MigrationBundlerV2](../src/migration/AaveV3MigrationBundlerV2.sol)
- [AaveV3OptimizerMigrationBundlerV2](../src/migration/AaveV3OptimizerMigrationBundlerV2.sol)
- [ChainAgnosticBundlerV2](../src/chain-agnostic/ChainAgnosticBundlerV2.sol)
- [CompoundV2MigrationBundlerV2](../src/migration/CompoundV2MigrationBundlerV2.sol)
- [CompoundV3MigrationBundlerV2](../src/migration/CompoundV3MigrationBundlerV2.sol)
- [EthereumBundlerV2](../src/ethereum/EthereumBundlerV2.sol)

## Getting started

To verify a specification, run the command `certoraRun Spec.conf` where `Spec.conf` is one of the configuration files in [`certora/confs`](confs).

You must have set the `CERTORAKEY` environment variable to a valid Certora key.

## Overview

Bundler methods used during a bundle execution have the `protected` modifier. This modifier ensures that:
- an initiator has been set;
- the caller is the bundle initiator or the Morpho contract.

The `Protected.spec` file checks that all bundler functions, except noted exceptions, respect the requirements of the `protected` modifier when an initiator has been set.

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Protected.spec`](specs/Protected.spec) checks that all methods except noted exceptions respect the `protected` modifier when an initiator has been set.

The [`certora/confs`](confs) folder contains a configuration file for each deployed bundler.
