export enum PlatformType {
  Snapshot = 0,
  Polygon = 1,
}

const snapshotConfig = {
  rinkeby: {
    znsHub: "0x90098737eB7C3e73854daF1Da20dFf90d521929a",
  },
  mainnet: {
    znsHub: "0x6141d5cb3517215a03519a464bf9c39814df7479",
  },
};

export const config = { ...snapshotConfig };
