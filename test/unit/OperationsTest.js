import {increasetimeto, duration} from '../helpers/increaseTime.js';
import {assertevent, assertnoevent} from '../helpers/assertEvent.js';

const promise = require("bluebird");
const wallet = artifacts.require("./Operations.sol");

const getblocknumber = promise.promisify(web3.eth.getBlockNumber);
const getblock = promise.promisify(web3.eth.getBlock);

contract('operations', function(accounts) {
    let defaultUser = web3.eth.accounts[0];
    let signer1 = web3.eth.accounts[1];
    let signer2 = web3.eth.accounts[2];
    let signer3 = web3.eth.accounts[3];
    let recipient = web3.eth.accounts[4];
    let otherUser = web3.eth.accounts[5];
    let newOwner = web3.eth.accounts[6];
    let otherUser2 = web3.eth.accounts[7];

    describe("Setup", () => {
        let operations;

        beforeEach(() => {
            return Promise.resolve()
                .then(() => Operations.new())
                .then((_operations) => operations = _operations)
        });

        it("should have inited", function() {
            return Promise.resolve()
                .then(() => assert(operations.latestFork.equals(10),
                                   `Should have 10 as latest fork index`))

                .then(() => assert(operations.clientsRequired.equals(1),
                                   `Should have 1 required client`))
        });
    });
});
