//! Outer relay set validator contract managed by the majority of validators.
//! Copyright Parity Technologies Ltd (UK), 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.15;

import "./base/ValidatorManaged.sol";
import "./base/RelaySet.sol";

contract OuterValidatorManagedSet is ValidatorManaged, OuterSet {
  function OuterValidatorManagedSet(address _validators)
    ValidatorManaged(_validators)
    OuterSet(_validators)
    public
  {}

  function setInner(address _inner, uint8[] v, bytes32[] r, bytes32[] s) public {
    bytes32 opHash = keccak256(_inner, nonce);
    checkValidatorMajority(opHash, v, r, s);
    validators = InnerSet(_inner);
  }
}
