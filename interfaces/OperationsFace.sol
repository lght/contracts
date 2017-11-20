pragma solidity ^0.4.11;

interface OperationsFace {
	function proposeTransaction(bytes32 _txid, address _to, bytes _data, uint _value, uint _gas) public returns (uint txSuccess);
	function confirmTransaction(bytes32 _txid) public returns (uint txSuccess);
	function rejectTransaction(bytes32 _txid) public;
	function proposeFork(uint32 _number, bytes32 _name, bool _hard, bytes32 _spec) public;
	function acceptFork() public;
	function rejectFork() public;
	function setClientOwner(address _newOwner) public;
	function addRelease(bytes32 _release, uint32 _forkBlock, uint8 _track, uint24 _semver, bool _critical) public;
	function addChecksum(bytes32 _release, bytes32 _platform, bytes32 _checksum) public;

	function isLatest(bytes32 _client, bytes32 _release) constant public returns (bool);
	function track(bytes32 _client, bytes32 _release) constant public returns (uint8);
	function latestInTrack(bytes32 _client, uint8 _track) constant public returns (bytes32);
	function build(bytes32 _client, bytes32 _checksum) constant public returns (bytes32 o_release, bytes32 o_platform);
	function release(bytes32 _client, bytes32 _release) constant public returns (uint32 o_forkBlock, uint8 o_track, uint24 o_semver, bool o_critical);
	function checksum(bytes32 _client, bytes32 _release, bytes32 _platform) constant public returns (bytes32);
}

contract OperationsProxyFace is OperationsFace {
	function clientOwner(address _owner) constant public returns (bytes32);
}
