# Bundler3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for [Bundler3](../src/Bundler3.sol).

## Getting started

This project depends on several [Solidity](https://soliditylang.org/) versions which are required for running the verification.
The compiler binaries should be available at the paths:

- `solc-0.4.19` for the solidity compiler version `0.4.19`;
- `solc-0.8.19` for the solidity compiler version `0.8.19`;
- `solc-0.8.17` for the solidity compiler version `0.8.17`;
- `solc-0.8.28` for the solidity compiler version `0.8.28`.

To verify a specification, run the command `certoraRun Spec.conf` where `Spec.conf` is the configuration file of the matching CVL specification.
Configuration files are available in [`certora/confs`](confs).
Please ensure that `CERTORAKEY` is set up in your environment.

## Overview

The Bundler3 contract enables an EOA to call different endpoint contracts onchain as well as grouping several calls in a single bundle.
These calls may themselves reenter the Bundler3 contract.

## Bundler3 safety restrictions

A key feature of the bundler is to restrict reentering in adapter calls.
In particular, it is checked that reentering an adapter is only possible during a multicall execution.
It is also checked that adapters' methods used during a bundle execution may only be called by the Bundler3 contract.
Additionally, the verification makes sure that it's only possible to reenter the adapter using a dedicated Bundler3 function.
Bundler3 uses transient storage, it's checked that it's nullified on each entry-point call.
This is checked with a separate configuration as it requires to disable sanity-checks (because `reenter` cannot be an entry-point _per se_).

## Morpho Zero Conditions

Some adapters may call Morpho entry-points, we check that zero inputs that should revert on Morpho revert directly at the adapter level.

## Allowance isolation

During the execution of an adapter, ERC20 allowance of that adapter to another contract may increase.
It is checked that such allowance is reset to zero at the end of the execution.
Note that this is not verified for the Paraswap adapter.

## General adapter reverts

When calling a function of this adapter, it is verified that either the state changes or the execution reverts.
This property doesn't hold for every function of the adapters, in those cases a dedicated rule justifying this is included.

### Folders and file structure

The [`certora/specs`](specs) folder contains these files:

- [`Bundler3.spec`](specs/Bundler3.spec) describes entry points safety;
- [`AllowancesInvariant.spec`](specs/AllowancesInvariant.spec) describes allowance isolation;
- [`GeneralAdapter1Reverts.spec`](specs/GeneralAdapter1Reverts.spec) describes when state should change or execution reverts;
- [`MorphoZeroConditions.spec`](specs/MorphoZeroConditions.spec) describes how calls to Morpho with zero should behave;
- [`OnlyBundler3.spec`](specs/OnlyBundler3.spec) describes that adapters' methods may only be called by the Bundler3;
- [`ReenterCaller.spec`](specs/ReenterCaller.spec) describes Bundler3 reentering properties;
- [`TransientStorageInvariant.spec`](specs/TransientStorageInvariant.spec) describes the transient storage behavior.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The Bundler3 interacts with contracts implementing the interfaces of standards such as the ERC20 or ER4626.
In the specifications these implementations are left abstract.
During the verification process, they are instantiated with a set of user provided contracts.
In this project we include some of the common distributions of these standards in the directories:

- [lib/morpho-blue/certora/dispatch](../lib/morpho-blue/certora/dispatch);
- [test/helpers/mocks](../test/helpers/mocks);
- [certora/dispatch](dispatch).
