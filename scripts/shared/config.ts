export enum PlatformType {
  Snapshot = 0,
  Polygon = 1,
}

type ethereumNetwork = "goerli" | "mainnet";
type polygonNetwork = "polygonMumbai" | "polygon";

interface EthereumConfig {
  zDAORegistry: string;
  // refer link: https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer
  checkpointManager: string;
  fxRoot: string;
}

interface PolygonConfig {
  // refer link: https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer
  fxChild: string;
  // refer link: https://docs.polygon.technology/docs/develop/ethereum-polygon/submit-mapping-request/#mapping-checklist
  childChainManager: string;
}

const ethereumConfig: { [key in ethereumNetwork]: EthereumConfig } = {
  goerli: {
    zDAORegistry: "0xC9d640CB7a1Cdfa02b31f0AE36c239380B493448", // todo
    checkpointManager: "0x2890bA17EfE978480615e330ecB65333b880928e",
    fxRoot: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  mainnet: {
    zDAORegistry: "", // todo
    checkpointManager: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    fxRoot: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
  },
};

const polygonConfig: { [key in polygonNetwork]: PolygonConfig } = {
  polygonMumbai: {
    fxChild: "0xCf73231F28B7331BBe3124B907840A94851f9f11",
    childChainManager: "0xb5505a6d998549090530911180f38aC5130101c6",
  },
  polygon: {
    fxChild: "0x8397259c983751DAf40400790063935a11afa28a",
    childChainManager: "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa",
  },
};

const snapshotConfig = {
  rinkeby: {
    zDAORegistry: "0x9c870c0B043E8ce4a7CFa31e82185C7a07fA3573",
  },
  mainnet: {
    zDAORegistry: "",
  },
};

export const zDAOChefConfig = {
  ...snapshotConfig,
  ...ethereumConfig,
  ...polygonConfig,
};

export const zDAORegistryConfig = {
  rinkeby: {
    zNSHub: "0x90098737eB7C3e73854daF1Da20dFf90d521929a",
    zNAResolver: "0x7Cca4a260a6A178dCcEe0DC19f4757E1D05cd38D",
  },
  goerli: {
    zNSHub: "0x9a35367c5e8C01cd009885e497a33a9761938832",
    zNAResolver: "0x67Fc897a30dA4c4409615476A3dC6716E32d4EB5",
  },
  mainnet: {
    zNSHub: "0x6141d5Cb3517215A03519A464bF9C39814df7479",
    zNAResolver: "",
  },
};
