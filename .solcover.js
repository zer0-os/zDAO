module.exports = {
  norpc: true,
  testCommand: 'yarn run test',
  compileCommand: 'yarn run compile',
  skipFiles: [
    'mock', 'oz', 'oz-upgradeable', 'polygon/tunnel', 'polygon/ethereum/FxStateEthereumTunnel.sol', 'polygon/polygon/FxStatePolygonTunnel.sol'
  ],
};