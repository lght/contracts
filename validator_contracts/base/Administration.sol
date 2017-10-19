//! A contract which performs non-standard state transitions with administrator privileges
//! by issuing log events.
//! Copyright Parity Technologies Ltd (UK), 2016.
//! By Robert Habermeier, 2017.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.15;

contract Administration {
    // Set the balance of the target to the new balance.
    event SetBalance(address indexed target, uint256 indexed newBalance);
}