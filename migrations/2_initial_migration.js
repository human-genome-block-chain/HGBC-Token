const HGBCToken = artifacts.require("HGBCToken");

module.exports = function(deployer) {
  deployer.deploy(HGBCToken);
};
