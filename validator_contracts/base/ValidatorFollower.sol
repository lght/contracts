//! Contract which looks up validator set.
//! Copyright Parity Technologies Ltd (UK), 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.16;

import "./ValidatorSet.sol";

contract ValidatorFollower {
  ValidatorSetGetter validators;

  function ValidatorFollower(address _validators) public {
    validators = ValidatorSetGetter(_validators);
  }

  // Extracts the internal validator set.
  // Requires byzantium changes to work (returndatasize/returndatacopy).
  function getValidatorsInternal() internal constant returns (address[]) {
    // signature of getValidators function
    bytes4 methodSig = 0xb7ab4db5;
    address addr = validators;
    uint256 gasToUse = msg.gas - 1000;

    assembly {
      mstore(0x10, methodSig)
      let ret := call(gasToUse, addr, 0, 0x10, 4, 0, 0)
      jumpi(0x02,iszero(ret))
      returndatacopy(0, 0, returndatasize)
      return(0, returndatasize)
    }
  }
}
