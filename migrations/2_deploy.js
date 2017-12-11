var TCR = artifacts.require("./TCR.sol");
var TestToken = artifacts.require("./TestToken.sol");

module.exports = function(deployer) {
  if (false) {
    return deployer.deploy(TestToken).then(function () {
      return deployer.deploy(TCR, TestToken.address);
    });
  }
};