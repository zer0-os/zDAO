# ZDAORegistry-subgraph

## Example

Subgraph: QmS1mAWu6zWLhXwFqPedNt8sdKynJdgMbirWANdcdyXm25

Deployed to https://api.thegraph.com/subgraphs/name/zer0-os/zdao-registry-rinkeby

Subgraph endpoints:

Queries (HTTP): https://api.thegraph.com/subgraphs/name/zer0-os/zdao-registry-rinkeby

Subscriptions (WS): wss://api.thegraph.com/subgraphs/name/zer0-os/zdao-registry-rinkeby

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

Check docker log

```
docker container logs <NODE NAME>
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
