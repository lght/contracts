pragma solidity ^0.4.18;

contract TestOperations
{
	address target_contract;
	address owner;

	function TestOperations()
		public
	{
		owner = msg.sender;
	}

	function set_target_contract(address _target)
		public
	{
		target_contract = _target;
	}

	function test_init()
		public
	{
		assert(target_contract.call.value(msg.value)());
	}
}
