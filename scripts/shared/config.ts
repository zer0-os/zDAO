export enum PlatformType {
  Snapshot = 0,
  Polygon = 1,
}

type ethereumNetwork = "rinkeby" | "goerli" | "mainnet";

interface ZDAOModuleConfig {
  // Address to Gnosis Safe wallet
  gnosisSafeProxy: string;
}

const moduleConfig: { [key in ethereumNetwork]: ZDAOModuleConfig } = {
  rinkeby: {
    gnosisSafeProxy: "", // todo
  },
  goerli: {
    gnosisSafeProxy: "", // todo
  },
  mainnet: {
    gnosisSafeProxy: "", // todo
  },
};

export default {
  module: moduleConfig,
};
