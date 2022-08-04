# ZDAORegistry-subgraph

## Example

Subgraph: QmcTJZ1aqKTx5jPUnKUJ799BYwBpwbDya12GSseH8W4YdN

Deployed to https://thegraph.com/explorer/subgraph/deep-quality-dev/zdao-registry

Subgraph endpoints:

Queries (HTTP): https://api.thegraph.com/subgraphs/name/deep-quality-dev/zdao-registry

Subscriptions (WS): wss://api.thegraph.com/subgraphs/name/deep-quality-dev/zdao-registry

## Deploy on Local

You can run graph node/ipfs/postgres on the docker and deploy.

Reference: https://thegraph.academy/developers/local-development/

### Run graph node on docker

`docker-compose.yml` has configuration for graph-node/ipfs/postgres and rinkeby forking configuration.

If you are going to fork mainnet, you should update the following line in `docker-compose.yml`:

```
ethereum: "rinkeby:https://eth-rinkeby.alchemyapi.io/v2/l1u0wuvuvoqtYye4fFuY9C3NGZFKWhXC"
```

Run docker

```
docker-compose up -d
```

### Remove endpoint

If you already deployed on the local node, you can run the following command.

```
yarn remove-local --access-token <ACCESS TOKEN> <GITHUB NAME/REPO>
```

### Create new endpoint

```
yarn create-local --access-token <ACCESS TOKEN> <GITHUB NAME/REPO>
```

### Deploy endpoint

```
yarn deploy-local --access-token <ACCESS TOKEN> <GITHUB NAME/REPO>
```

## Deploy on Rinkeby

You can find the Access Token on the dashboard page of [Hosted Service] section.

Reference: https://thegraph.com/docs/en/deploying/deploying-a-subgraph-to-hosted/

```
yarn internal:deploy <GITHUB NAME/REPO> --access-token <ACCESS TOKEN>
```

## Deploy on Mainnet

Reference: https://thegraph.com/docs/en/deploying/deploying-a-subgraph-to-studio/

### Auth

```
graph auth --studio <DEPLOY KEY>
```

### Deploy

```
graph deploy --studio <SUBGRAPH_SLUG>
```
