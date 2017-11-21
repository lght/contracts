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

	function delegate(bytes _data)
		public
		payable
	{
		assert(target_contract.call.value(msg.value)(_data));
	}

	// Assert operations contract
	//   is initialized
	//   has a payable fallback function
	function test_init()
		public
		payable
	{
		assert(target_contract.call.value(msg.value)());
	}

	// Assert operations.isLatest() returns true for a given client and release
	function test_is_latest_returns_true(bytes is_latest)
		public
	{
		assert(target_contract.call(is_latest));
	}
}
