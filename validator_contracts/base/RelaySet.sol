//! Outer and inner contracts that form a relay validator set.
//! OuterSet maintains general invariants and provides an interface to the Engine,
//! while the InnetSet implements most of the validator logic
//! and can be swapped out via the OuterSet.
//! Copyright Parity Technologies Ltd (UK), 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.16;

import "./ValidatorFollower.sol";
import "./ValidatorSet.sol";

contract OuterSet is ValidatorSet, ValidatorFollower {
  // System address, used by the block sealer.
  address constant SYSTEM_ADDRESS = 0xfffffffffffffffffffffffffffffffffffffffe;
  bytes4 SIGNATURE = 0xb7ab4db5;

  modifier only_system_and_not_finalized() {
    require(msg.sender == SYSTEM_ADDRESS && !finalized);
    _;
  }

  modifier only_inner() {
    require(msg.sender == address(validators));
    _;
  }

  InnerSet public validators;
  // Was the last validator change finalized.
  bool public finalized;

  function OuterSet(address _validators) ValidatorFollower(_validators) public {}

  // For validators.
  function initiateChange(bytes32 _parent_hash, address[] _new_set) public only_inner {
    finalized = false;
    InitiateChange(_parent_hash, _new_set);
  }

  // For sealer.
  function finalizeChange() public only_system_and_not_finalized {
    finalized = true;
    validators.finalizeChange();
  }

  function getValidators() public constant returns (address[]) {
    return getValidatorsInternal();
  }

  function reportBenign(address validator, uint256 blockNumber) public {
    validators.reportBenign(validator, blockNumber);
  }

  function reportMalicious(address validator, uint256 blockNumber, bytes proof) public {
    validators.reportMalicious(validator, blockNumber, proof);
  }
}

contract InnerSet is ValidatorSetGetter {
  OuterSet public outerSet;

  modifier only_outer() {
    require(msg.sender == address(outerSet));
    _;
  }

  function finalizeChange() public;
  function reportBenign(address validator, uint256 blockNumber) public;
  function reportMalicious(address validator, uint256 blockNumber, bytes proof) public;
}
