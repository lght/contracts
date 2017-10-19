//! Contract for which some functions require the approval of validator majority.
//! Requires signatures to be collected offline, although a wrapper contract
//! could be implemented to collect signatures online.
//! Copyright Parity Technologies Ltd (UK), 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.16;

import "./ValidatorFollower.sol";

contract ValidatorManaged is ValidatorFollower {
  uint256 nonce = 0;

  function ValidatorManaged(address _validators) ValidatorFollower(_validators) public {}

  // Checks that the signatures sign the operation hash and increments the nonce
  // if successful. Operation hash should always include the nonce.
  //
  // Signatures must be in the same order as validators in getValidators to
  // reduce computational complexity.
  // Pass 3 arrays for the signatures, where the i'th signature
  // is obtained from (v[i], r[i], s[i]).
  function checkValidatorMajority(bytes32 hash, uint8[] v, bytes32[] r, bytes32[] s) internal {
    require(v.length == r.length && r.length == s.length);
    address[] memory currentValidators = getValidatorsInternal();
    uint valIndex = 0;
    uint numSigned = 0;

    // a simple majority is enough because the state changes enacted
    // by this contract are protected by alternate finality
    // guarantees.
    var threshold = (currentValidators.length / 2) + 1;

    // check each signature against the validators.
    var numSigs = r.length;
    for (uint sigIndex = 0; sigIndex < numSigs; sigIndex++) {
      if (numSigned == threshold) {
        break;
      }

      var signer = ecrecover(hash, v[sigIndex], r[sigIndex], s[sigIndex]);
      assert(signer != 0);

      while (valIndex < currentValidators.length) {
        var valAddr = currentValidators[valIndex];
        valIndex += 1;

        // found our signer. move on to the next
        // signature.
        if (valAddr == signer) {
          numSigned += 1;
          break;
        }
      }
    }

    // if enough validators signed the message,
    // increase the nonce.
    require(numSigned >= threshold);
    nonce += 1;
  }
}
