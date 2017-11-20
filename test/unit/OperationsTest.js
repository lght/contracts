import {increaseTimeTo, duration} from '../helpers/increaseTime.js';
import {assertEvent, assertNoEvent} from '../helpers/assertEvent.js';

const Promise = require("bluebird");
const Operations = artifacts.require("./Operations.sol");

const getBlockNumber = Promise.promisify(web3.eth.getBlockNumber);
const getBlock = Promise.promisify(web3.eth.getBlock);

contract('Operations', function(accounts) {
    let defaultUser = web3.eth.accounts[0];

    describe("Setup", () => {
		let operations;

        beforeEach(function() {
			return Promise.resolve()
				.then(function() { return Operations.deployed() })
				.then(function(ops) { operations = ops; return ops })
		});

        it.only("should have inited", function() {
            return operations.latestInTrack("parity", 1)
        });
    });
});
