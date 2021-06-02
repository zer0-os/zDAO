const ZDao = artifacts.require('ZDao');

contract('ZDao', function (accounts) {
  const [ other ] = accounts;
  console.log(other);
  before(async function (){

  })
  beforeEach(async function () {

  });
  //inactive
  context('with valid ZNA', function () {
    it('should successfully create an associated ZDAO', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully set DAO token', async function () {

    });
  });
  
  context('with inactive ZDAO', function () {
    it('should successfully set Voting type absolute', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully set Voting type relative', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully set proposal time limit', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully set proposal success threshold', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully add contract address to safelist', async function () {

    });
  });
  context('with inactive ZDAO', function () {
    it('should successfully activate DAO', async function () {

    });
  });
  //active
  context('with active ZDAO', function () {
    it('should successfully propose adding contract address to safelist', async function () {

    });
  });
  context('on reaching successful vote threshold', function () {
    it('should successfully add contract address to safelist', async function () {

    });
  });
  context('with safelisted contract', function () {
    it('should successfully propose contract call', async function () {

    });
  });
  context('on reaching successful vote threshold', function () {
    it('should successfully execute contract call', async function () {

    });
  });
  context('with active ZDAO', function () {
    it('should successfully propose adding new neuron', async function () {

    });
  });
  context('on reaching successful vote treshold', function () {
    it('should successfully add neuron', async function () {

    });
  });
  context('with neuron installed', function () {
    it('should successfully execute call from neuron', async function () {

    });
  });
  context('with active ZDAO', function () {
    it('should successfully upgrade DAO and transfer state', async function () {

    });
  });
});