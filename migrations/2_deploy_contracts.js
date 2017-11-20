var Wallet = artifacts.require("./Wallet.sol");
var Operations = artifacts.require("./Operations.sol");

module.exports = function(deployer) {
	deployer.deploy(Operations);
};
