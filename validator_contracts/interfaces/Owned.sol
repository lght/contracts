//! Owned contract.
//! Copyright Parity Technologies Ltd (UK), 2016.
//! By Gav Wood, 2016.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.15;

contract Owned {
	modifier only_owner { require(msg.sender == owner); _; }

	event NewOwner(address indexed old, address indexed current);

	function setOwner(address _new) public only_owner { NewOwner(owner, _new); owner = _new; }

	address public owner = msg.sender;
}
