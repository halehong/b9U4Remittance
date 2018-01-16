var Remittance = artifacts.require("./Remittance.sol");
var Base = artifacts.require("./Base.sol");

module.exports = function(deployer) {
  deployer.deploy(Base);
  deployer.deploy(Remittance);
};
