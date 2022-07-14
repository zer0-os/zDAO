# Voting on Snapshot

## Overview

[Snapshot](https://snapshot.org) is a voting system where projects can create a proposal for people to vote, this is a popular tool for decentralized organizations(DAO).

Snapshot has lots of spaces for DAO, every space has its own ENS.
We call this DAO `zDAO` with an association of proper `zNA`s.

As above, associations are registered in `ZDAORegistry`, detailed `zDAO` information is in `SnapshotZDAOChef` which is inherited from `IZDAOFactory``.

Every `zDAO` has ENS and an address to Gnosis Safe Wallet.
Once created space in [Snapshot](https://snapshot.org), we should register it in `ZDAORegistry`, only registered `zDAO`s will be listed in the SDK.

## Deploying

### Pre-requisite

`ZDAORegistry` should be deployed in the working network and configured in [config.ts](../../scripts/shared/config.ts#L33).

### Deploy

In the command line terminal, run the following:

```
yarn deploy-snapshot goerli
```

This command deploys `SnapshotZDAOChef` and registers it as `IZDAOFactory` in `ZDAORegistry`.

### Create new `zDAO`

After create DAO in Snapshot, we should call `addNewZDAO` function in `ZDAORegistry` to register with Gnosis Safe wallet address and ENS.
