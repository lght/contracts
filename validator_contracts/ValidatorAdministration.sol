//! An administration contract which draws from the current set of validators.
//! Majority support is required to enact events.
//! Signatures should be collected offline or with a wrapper contract.
//!
//! Copyright Parity Technologies Ltd (UK), 2016.
//! By Robert Habermeier, 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.16;

import "./base/ValidatorManaged.sol";
import "./base/Administration.sol";

/// Validator set based administration. Requires signatures to be collected
/// offline, although a wrapper contract could be implemented to collect signatures
/// online.
contract ValidatorBasedAdministration is Administration, ValidatorManaged {
  function ValidatorBasedAdministration(address _validators)
    ValidatorManaged(_validators)
    public
  {}

  // set the balance of the given account to the new balance, with supporting signatures
  // from a majority of validators.
  function setBalance(address target, uint256 newBalance, uint8[] v, bytes32[] r, bytes32[] s) {
    bytes32 opHash = keccak256(target, newBalance, nonce);
    checkValidatorMajority(opHash, v, r, s);

    SetBalance(target, newBalance);
  }
}
