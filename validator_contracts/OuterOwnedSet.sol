//! Outer relay set validator contract managed by an owner.
//! Copyright Parity Technologies Ltd (UK), 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.15;

import "./base/Owned.sol";
import "./base/RelaySet.sol";

contract OuterOwnedSet is Owned, OuterSet {
  function OuterOwnedSet(address _validators) OuterSet(_validators) public {}

  function setInner(InnerSet _inner) public only_owner {
    validators = _inner;
  }
}
