export enum PlatformType {
  Snapshot = 0,
  Polygon = 1,
}

type ethereumNetwork = "rinkeby" | "goerli" | "mainnet";

interface ZDAOModuleConfig {
  // Address to Gnosis Safe wallet
  gnosisSafeProxy: string;
  // Admin address who can grant a Gnosis Safe owner an executor role
  // so he can execute proposal
  organizer: string;
}

const moduleConfig: { [key in ethereumNetwork]: ZDAOModuleConfig } = {
  rinkeby: {
    gnosisSafeProxy: "", // todo
    organizer: "", // todo
  },
  goerli: {
    gnosisSafeProxy: "", // todo
    organizer: "", // todo
  },
  mainnet: {
    gnosisSafeProxy: "", // todo
    organizer: "", // todo
  },
};

export default {
  module: moduleConfig,
};
