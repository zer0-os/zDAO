export enum PlatformType {
  Snapshot = 0,
  Polygon = 1,
}

type ethereumNetwork = "goerli" | "mainnet";
type polygonNetwork = "polygonMumbai" | "polygon";

interface EthereumConfig {
  zNSHub: string;
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
    zNSHub: "0x9a35367c5e8C01cd009885e497a33a9761938832", // todo
    zDAORegistry: "", // todo
    checkpointManager: "0x2890bA17EfE978480615e330ecB65333b880928e",
    fxRoot: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  mainnet: {
    zNSHub: "0x6141d5cb3517215a03519a464bf9c39814df7479",
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

interface zNSHubConfig {
  domain: string; // zNA
  owner: string; // owner wallet address
}

// only used in MockzNSHub on Goerli network
export const zNSHubConfig: zNSHubConfig[] = [
  {
    domain: "wilder.kicks",
    owner: "0x22C38E74B8C0D1AAB147550BcFfcC8AC544E0D8C",
  },
  {
    domain: "wilder.wheels",
    owner: "0x22C38E74B8C0D1AAB147550BcFfcC8AC544E0D8C",
  },
];

const snapshotConfig = {
  rinkeby: {
    zNSHub: "0x7F918CbbBf37e4358ad5f060F15110151d14E59e", // "0x90098737eB7C3e73854daF1Da20dFf90d521929a",
    zDAORegistry: "0x2ae829089678d90027279ab36AE99928F53D8b9e",
  },
  mainnet: {
    zNSHub: "0x6141d5cb3517215a03519a464bf9c39814df7479",
    zDAORegistry: "",
  },
};

export const config = {
  ...snapshotConfig,
  ...ethereumConfig,
  ...polygonConfig,
};
