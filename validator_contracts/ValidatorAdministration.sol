//! An administration contract which draws from the current set of validators.
//! Majority support is required to enact events.
//! Signatures should be collected offline or with a wrapper contract.
//!
//! Copyright Parity Technologies Ltd (UK), 2016.
//! By Robert Habermeier, 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.16;

import "./interfaces/ValidatorSet.sol";
import "./interfaces/Administration.sol";

/// Validator set based administration. Requires signatures to be collected
/// offline, although a wrapper contract could be implemented to collect signatures
/// online.
contract ValidatorBasedAdministration is Administration {
    uint256 constant SIG_LEN = 65;

    uint256 nonce;
    ValidatorSet validators;

    // pass 3 arrays for the signatures, where the i'th signature
    // is obtained from (v[i], r[i], s[i]).
    modifier valid_sig_length(uint8[] v, bytes32[] r, bytes32[] s) {
        assert(v.length == r.length && r.length == s.length);
        _;
    }

    function ValidatorBasedAdministration(ValidatorSet _validators) public {
        nonce = 0;
        validators = _validators;
    }

    // extracts the internal validator set.
    // requires byzantium changes to work (returndatasize/returndatacopy)
    function getValidatorsInternal() internal constant returns (address[]) {
        // signature of getValidators function
        bytes4 METHOD_SIG = 0xb7ab4db5;
        address addr = validators;
        uint256 gas = msg.gas;

        assembly {
            mstore(0x10, METHOD_SIG)
            let ret := call(gas, addr, 0, 0x10, 4, 0, 0)
            jumpi(0x02,iszero(ret))
            returndatacopy(0, 0, returndatasize)
            return(0, returndatasize)
        }
    }

    // checks that the signatures sign the operation hash and increments the nonce
    // if successful.
    //
    // signatures must be in the same order as validators in getValidators to
    // reduce computational complexity.
    function check_op_hash_sigs(bytes32 hash, uint8[] v, bytes32[] r, bytes32[] s) internal {
        address[] memory currentValidators = getValidatorsInternal();
        uint val_index = 0;
        uint n_signed = 0;

        var threshold = (currentValidators.length / 2) + 1;

        // check each signature against the validators.
        var n_sigs = r.length;
        for (uint sig_index = 0; sig_index * SIG_LEN < n_sigs; sig_index++) {
            if (n_signed == threshold) { break; }

            var signer = ecrecover(hash, v[sig_index], r[sig_index], s[sig_index]);
            assert(signer != 0);

            while (val_index < currentValidators.length) {
                var val_addr = currentValidators[val_index];
                val_index += 1;

                // found our signer. move on to the next
                // signature.
                if (val_addr == signer) {
                    n_signed += 1;
                    break;
                }
            }
        }

        // if enough validators signed the message,
        // increase the nonce.
        assert(n_signed >= threshold);
        nonce += 1;
    }

    // set the balance of the given account to the new balance, with supporting signatures
    // from a majority of validators.
    function setBalance(address target, uint256 newBalance, uint8[] v, bytes32[] r, bytes32[] s)
        public valid_sig_length(v, r, s)
    {
        bytes32 o_hash = keccak256(target, newBalance, nonce);
        check_op_hash_sigs(o_hash, v, r, s);

        SetBalance(target, newBalance);
    }
}