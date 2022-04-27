type ethereumNetwork = "goerli" | "mainnet";
type polygonNetwork = "polygonMumbai" | "polygon";

interface EthereumConfig {
  znsHub: string;
  // refer link: https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer
  checkpointManager: string;
  fxRoot: string;
}

interface PolygonConfig {
  // refer link: https://docs.polygon.technology/docs/develop/l1-l2-communication/state-transfer
  fxChild: string;
}

const ethereumConfig: { [key in ethereumNetwork]: EthereumConfig } = {
  goerli: {
    znsHub: "0x9a35367c5e8C01cd009885e497a33a9761938832", // todo
    checkpointManager: "0x2890bA17EfE978480615e330ecB65333b880928e",
    fxRoot: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  mainnet: {
    znsHub: "0x6141d5cb3517215a03519a464bf9c39814df7479",
    checkpointManager: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    fxRoot: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
  },
};

const polygonConfig: { [key in polygonNetwork]: PolygonConfig } = {
  polygonMumbai: {
    fxChild: "0xCf73231F28B7331BBe3124B907840A94851f9f11",
  },
  polygon: {
    fxChild: "0x8397259c983751DAf40400790063935a11afa28a",
  },
};

export const config = { ...ethereumConfig, ...polygonConfig };

interface ZNSHubConfig {
  domain: string; // zNA
  owner: string; // owner wallet address
}

// only used in MockZNSHub on Goerli network
export const znsHubConfig: ZNSHubConfig[] = [
  {
    domain: "wilder.kicks",
    owner: "0x22C38E74B8C0D1AAB147550BcFfcC8AC544E0D8C",
  },
  {
    domain: "wilder.wheels",
    owner: "0x22C38E74B8C0D1AAB147550BcFfcC8AC544E0D8C",
  },
];
