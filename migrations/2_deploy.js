var TCR = artifacts.require("./TCR.sol");
var TestToken = artifacts.require("./TestToken.sol");

module.exports = function(deployer) {
  if (false) {
    return deployer.deploy(TestToken).then(function () {
      return deployer.deploy(TCR, TestToken.address);
    });
  } else {
    // return deployer.deploy(TCR, '0x35d8830ea35e6Df033eEdb6d5045334A4e34f9f9')
    return deployer.deploy(TCR, '0xcc0604514f71b8d39e13315d59f4115702b42646')
    
  }
};