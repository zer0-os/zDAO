# Voting on Polygon

## Overview

To reduce the gas fees on voting, we decided to use Polygon for voting.

On Ethereum, `zNA` owners can create `zDAO` with:

- zNA: associated `zNA`
- gnosis safe address: address to Gnosis Safe wallet
- voting token: address to ERC20 or ERC721 on Ethereum, token holders can create a proposal.
- amount: minimum number of tokens required to become a proposal creator, proposal should be created on Ethereum as well.
- duration: time duration of proposals in seconds, all the proposals in `zDAO` have the same duration.
- voting threshold: threshold in 100% as 10000 required to check if a given proposal is succeeded,
- minimum voting participants: number of voters in support of a proposal required in order for a vote to succeed
- minimum total voting tokens: number of votes in support of a proposal required in order for a vote to succeed
- relative majority: flag marking if relative majority to calculate a voting result

On Ethereum, voting token holders can create a proposal.

The created `zDAO`s and proposals are automatically synchronized to Polygon, users can cast a vote on Polygon.

- Voting tokens on Ethereum should be mapped to Polygon.
- Users can transfer voting tokens from Ethereum to Polygon through bridges to participate in voting.

  > Goerli to Mumbai: https://wallet-dev.polygon.technology/bridge/

  > Ethereum to Polygon: https://wallet.polygon.technology/bridge/

- Users can get voting power on Polygon as much as they staked mapped voting tokens on Polygon.

- If the proposal ends, the voting result will be transferred to Ethereum for execution.

### Collaboration

[<img src="./Collaboration.png" width="600px"/>](./Collaboration.png)

Polygon supports transfer states using [PoS](https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer) between Ethereum and Polygon.

## Deploying

### Pre-requisite

`ZDAORegistry` should be deployed in the working network and be configured in [config.ts](../../scripts/shared/config.ts#L33).

### Deploy

We need to deploy contracts on Ethereum and Polygon and map two contracts for state transfer.

1. Deploy on Ethereum

In the command line terminal, run the following:

```
yarn deploy-polygon:ethereum goerli
```

This command deploys `FxStateEthereumTunnel` and `EthereumZDAOChef`, and registers `EthereumZDAOChef` as `IZDAOFactory` in `ZDAORegistry`.

2. Deploy on Polygon

In the command line terminal, run the following:

```
yarn deploy-polygon:polygon polygonMumbai
```

This command deploys `FxStatePolygonTunnel`, `Staking` and `PolygonZDAOChef`.

## How to use Smart Contracts

1. Create a `zDAO` on Ethereum

   `addNewZDAO` in `EthereumZDAOChef` is called by `ZDAORegistry` contract with `zNA` and specific parameters for `zDAO`.

2. Remove a `zDAO` on Ethereum

   `removeZDAO` in `EthereumZDAOChef` is called by `ZDAORegistry` contract by Admin with `zDAOId`.

3. Create a proposal on Ethereum

   Call `createProposal` in `EthereumZDAOChef` with `zDAOId` and `ipfs` which contains proposal information.

4. Cancel a proposal on Ethereum

   Call `cancelProposal` in `EthereumZDAOChef` with `proposalId` and `zDAOId`.

5. Cast a vote on Polygon

   Call `vote` in `PolygonZDAOChef` with `zDAOId`, `proposalId` and user's `choice`.

6. Calculate a proposal result on Polygon

   Call `calculateProposal` in `PolygonZDAOChef` with `zDAOId` and `proposalId`.
   This will create a transaction and transfer state from Polygon to Ethereum.

7. Finalize a proposal result on Ethereum

   Once the transaction hash of calculating proposal is checkpointed, `PoS` mechanism generates bytes of payload.
   Call `receiveMessage` in `FxStateEthereumTunnel` with this payload.

8. Execute a proposal on Ethereum

   Call `executeProposal` in `EthereumZDAOChef` with `proposalId` and `zDAOId`.

9. Stake voting token on Polygon

   Call `stakeERC20` in `Staking` to stake ERC20 or call `stakeERC721` in `Staking` to stake ERC721.

## State transfer

[Polygon [docs](https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer#overview) explain how State transfer works.

As Polygon docs said, `FxBaseRootTunnel` and `FxBaseChildTunnel` should be mapped.

In our contracts, `FxStateEthereumTunnel` is inherited from `FxBaseRootTunnel`, `FxStatePolygonTunnel` is inherited from `FxBaseChildTunnel`.

- Open Etherscan of `FxStateEthereumTunnel` contract, and call `setPolygonStateTunnel` with the address to `FxStatePolygonTunnel`.
- Open PolygonScan of `FxStatePolygonTunnel`, and call `setEthereumStateTunnel` with the address to `FxStateEthereumTunnel`.

## Token Mapping

zDAO voting supports `ERC20` and `ERC721` as voting power.

To participate in voting, users should bridge `ERC20` and `ERC721` tokens from Ethereum to Polygon and stake on staking contracts before proposal creation.

Check out the [zDAO-token-mapping](https://github.com/zer0-os/zdao-token-mappings).
