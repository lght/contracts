// Operations contract, by Gavin Wood.
// Copyright Parity Technologies Ltd (UK), 2016.
// This code may be distributed under the terms of the Apache Licence, version 2.

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

contract Operations is OperationsFace {
	uint8 constant Stable = 1;
	uint8 constant Beta = 2;
	uint8 constant Nightly = 3;

	struct Release {
		uint32 forkBlock;
		uint8 track;
		uint24 semver;
		bool critical;
		mapping (bytes32 => bytes32) checksum;      // platform -> checksum
	}

	struct Build {
		bytes32 release;
		bytes32 platform;
	}

	struct Client {
		address owner;
		bool required;
		mapping (bytes32 => Release) release;
		mapping (uint8 => bytes32) current;
		mapping (bytes32 => Build) build;       // checksum -> Build
	}

	enum Status {
		Undecided,
		Accepted,
		Rejected
	}

	struct Fork {
		bytes32 name;
		bytes32 spec;
		bool hard;
		bool ratified;
		uint requiredCount;
		mapping (bytes32 => Status) status;
	}

	struct Transaction {
		uint requiredCount;
		mapping (bytes32 => Status) status;
		address to;
		bytes data;
		uint value;
		uint gas;
	}

	event Received(address indexed from, uint value, bytes data);
	event TransactionProposed(bytes32 indexed client, bytes32 indexed txid, address indexed to, bytes data, uint value, uint gas);
	event TransactionConfirmed(bytes32 indexed client, bytes32 indexed txid);
	event TransactionRejected(bytes32 indexed client, bytes32 indexed txid);
	event TransactionRelayed(bytes32 indexed txid, bool success);
	event ForkProposed(bytes32 indexed client, uint32 indexed number, bytes32 indexed name, bytes32 spec, bool hard);
	event ForkAcceptedBy(bytes32 indexed client, uint32 indexed number);
	event ForkRejectedBy(bytes32 indexed client, uint32 indexed number);
	event ForkRejected(uint32 indexed forkNumber);
	event ForkRatified(uint32 indexed forkNumber);
	event ReleaseAdded(bytes32 indexed client, uint32 indexed forkBlock, bytes32 release, uint8 track, uint24 semver, bool indexed critical);
	event ChecksumAdded(bytes32 indexed client, bytes32 indexed release, bytes32 indexed platform, bytes32 checksum);
	event ClientAdded(bytes32 indexed client, address owner);
	event ClientRemoved(bytes32 indexed client);
	event ClientOwnerChanged(bytes32 indexed client, address indexed old, address indexed now);
	event ClientRequiredChanged(bytes32 indexed client, bool now);
	event OwnerChanged(address old, address now);

	function Operations() 
		public	
	{
		// Is this constructor automatically called on deployment?
/*		// Mainnet
		fork[0] = Fork("frontier", keccak256("frontier"), true, true, 0);
		fork[1150000] = Fork("homestead", keccak256("homestead"), true, true, 0);
		fork[2463000] = Fork("eip150", keccak256("eip150"), true, true, 0);
		fork[2675000] = Fork("eip155", keccak256("eip155"), true, true, 0);
		latestFork = 2675000;
*/
		// Ropsten
		fork[0] = Fork("eip150", keccak256("eip150"), true, true, 0);
		fork[10] = Fork("eip155", keccak256("eip155"), true, true, 0);
		latestFork = 10;

		client["parity"] = Client(msg.sender, true);
		clientOwner[msg.sender] = "parity";
		clientsRequired = 1;
	}

	function() payable public { Received(msg.sender, msg.value, msg.data); }

	// Functions for client owners

	function proposeTransaction(bytes32 _txid, address _to, bytes _data, uint _value, uint _gas)
		public
		only_required_client_owner
		only_when_no_proxy(_txid)
		returns (uint txSuccess)
	{
		var client = clientOwner[msg.sender];
		proxy[_txid] = Transaction(1, _to, _data, _value, _gas);
		proxy[_txid].status[client] = Status.Accepted;
		txSuccess = checkProxy(_txid);

		// log transaction proposal
		TransactionProposed(client, _txid, _to, _data, _value, _gas);
	}

	function confirmTransaction(bytes32 _txid) 
		public
		only_required_client_owner
		only_when_proxy(_txid)
		only_when_proxy_undecided(_txid) 
		returns (uint txSuccess) 
	{
		var client = clientOwner[msg.sender];
		proxy[_txid].status[client] = Status.Accepted;
		proxy[_txid].requiredCount += 1;
		txSuccess = checkProxy(_txid);

		// log transaction confirmation
		TransactionConfirmed(client, _txid);
	}

	function rejectTransaction(bytes32 _txid)
		public
		only_required_client_owner
		only_when_proxy(_txid)
		only_when_proxy_undecided(_txid)
	{
		delete proxy[_txid];

		// log transaction rejection
		TransactionRejected(clientOwner[msg.sender], _txid);
	}

	function proposeFork(uint32 _number, bytes32 _name, bool _hard, bytes32 _spec)
		public
		only_client_owner
		only_when_none_proposed
	{
		fork[_number] = Fork(_name, _spec, _hard, false, 0);
		proposedFork = _number;

		// log fork proposal
		ForkProposed(clientOwner[msg.sender], _number, _name, _spec, _hard);
	}

	function acceptFork()
		public
		only_when_proposed
		only_undecided_client_owner
	{
		var newClient = clientOwner[msg.sender];
		fork[proposedFork].status[newClient] = Status.Accepted;
		ForkAcceptedBy(newClient, proposedFork);
		noteAccepted(newClient);
	}

	function rejectFork()
		public
		only_when_proposed
		only_undecided_client_owner
		only_unratified
	{
		var newClient = clientOwner[msg.sender];
		fork[proposedFork].status[newClient] = Status.Rejected;
		ForkRejectedBy(newClient, proposedFork);
		noteRejected(newClient);
	}

	function setClientOwner(address _newOwner)
		public
		only_client_owner
	{
		var newClient = clientOwner[msg.sender];
		clientOwner[msg.sender] = bytes32(0);
		clientOwner[_newOwner] = newClient;
		client[newClient].owner = _newOwner;
		ClientOwnerChanged(newClient, msg.sender, _newOwner);
	}

	function addRelease(bytes32 _release, uint32 _forkBlock, uint8 _track, uint24 _semver, bool _critical)
		public
		only_client_owner
	{
		var newClient = clientOwner[msg.sender];
		client[newClient].release[_release] = Release(_forkBlock, _track, _semver, _critical);
		client[newClient].current[_track] = _release;
		ReleaseAdded(newClient, _forkBlock, _release, _track, _semver, _critical);
	}

	function addChecksum(bytes32 _release, bytes32 _platform, bytes32 _checksum)
		public
		only_client_owner
	{
		var newClient = clientOwner[msg.sender];
		client[newClient].build[_checksum] = Build(_release, _platform);
		client[newClient].release[_release].checksum[_platform] = _checksum;
		ChecksumAdded(newClient, _release, _platform, _checksum);
	}

	// Admin functions

	function addClient(bytes32 _client, address _owner)
		public
		only_owner
	{
		client[_client].owner = _owner;
		clientOwner[_owner] = _client;
		ClientAdded(_client, _owner);
	}

	function removeClient(bytes32 _client)
		public
		only_owner
	{
		setClientRequired(_client, false);
		resetClientOwner(_client, 0);
		delete client[_client];
		ClientRemoved(_client);
	}

	function resetClientOwner(bytes32 _client, address _newOwner)
		public
		only_owner
	{
		var old = client[_client].owner;
		ClientOwnerChanged(_client, old, _newOwner);
		clientOwner[old] = bytes32(0);
		clientOwner[_newOwner] = _client;
		client[_client].owner = _newOwner;
	}

	function setClientRequired(bytes32 _client, bool _r)
		public
		only_owner
		when_changing_required(_client, _r)
	{
		ClientRequiredChanged(_client, _r);
		client[_client].required = _r;
		clientsRequired = _r ? clientsRequired + 1 : (clientsRequired - 1);
		ratifyFork();
	}

	function setOwner(address _newOwner)
		public
		only_owner
	{
		OwnerChanged(grandOwner, _newOwner);
		grandOwner = _newOwner;
	}

	// Getters

	function isLatest(bytes32 _client, bytes32 _release)
		constant
		public
		returns (bool)
	{
		return latestInTrack(_client, track(_client, _release)) == _release;
	}

	function track(bytes32 _client, bytes32 _release)
		constant
		public
		returns (uint8)
	{
		return client[_client].release[_release].track;
	}

	function latestInTrack(bytes32 _client, uint8 _track)
		constant
		public
		returns (bytes32)
	{
		return client[_client].current[_track];
	}

	function build(bytes32 _client, bytes32 _checksum)
		constant
		public
		returns (bytes32 o_release, bytes32 o_platform)
	{
		var b = client[_client].build[_checksum];
		o_release = b.release;
		o_platform = b.platform;
	}

	function release(bytes32 _client, bytes32 _release)
		constant
		public
		returns (uint32 o_forkBlock, uint8 o_track, uint24 o_semver, bool o_critical)
	{
		var b = client[_client].release[_release];
		o_forkBlock = b.forkBlock;
		o_track = b.track;
		o_semver = b.semver;
		o_critical = b.critical;
	}

	function checksum(bytes32 _client, bytes32 _release, bytes32 _platform)
		constant
		public
		returns (bytes32)
	{
		return client[_client].release[_release].checksum[_platform];
	}

	// Internals

	function noteAccepted(bytes32 _client)
		internal
		when_required(_client)
	{
		fork[proposedFork].requiredCount += 1;
		ratifyFork();
	}

	function noteRejected(bytes32 _client)
		internal 
		when_required(_client)
	{
		ForkRejected(proposedFork);
		delete fork[proposedFork];
		proposedFork = 0;
	}

	// maybe change the name here, so it semantically matches the intent?
	function ratifyFork()
		internal
		when_have_all_required
	{
		fork[proposedFork].ratified = true;
		latestFork = proposedFork;
		proposedFork = 0;

		// log fork ratification
		ForkRatified(proposedFork);
	}

	function checkProxy(bytes32 _txid)
		internal
		when_proxy_confirmed(_txid)
		returns (uint txSuccess)
	{
		var ptx = proxy[_txid];
		delete proxy[_txid];
		// TODO: refactor to use a push-pull pattern if possible
		//
		// state changes shouldn't occur after calling out to external
		// contract. 
		//
		// Mayb something like this would work:
		// firing off an event
		// then having the other contract listen
		// when the other contract hears that event, make the call below
		var success = ptx.to.call.value(ptx.value).gas(ptx.gas)(ptx.data);
		txSuccess = success ? 2 : 1;
		
		// log transaction relay
		TransactionRelayed(_txid, success);
	}

	// Modifiers

	modifier only_owner
	{
		require(grandOwner == msg.sender);
		_;
	}
	modifier only_client_owner {
		var newClient = clientOwner[msg.sender];
		require(newClient != 0);
		_;
	}
	modifier only_required_client_owner { 
		var newClient = clientOwner[msg.sender]; 
		require(client[newClient].required);
		_;
	}
	modifier only_ratified{
		assert(fork[proposedFork].ratified);
		_;
	}
	modifier only_unratified
	{
		assert(!fork[proposedFork].ratified);
		_;
	}
	modifier only_undecided_client_owner {
		var newClient = clientOwner[msg.sender];
		require(newClient != 0);
		require(fork[proposedFork].status[newClient] == Status.Undecided);
		_;
	}
	modifier only_when_none_proposed
	{
		assert(proposedFork == 0);
		_;
	}
	modifier only_when_proposed
	{
		assert(fork[proposedFork].name != 0);
		_;
	}
	modifier only_when_proxy(bytes32 _txid)
	{
		assert(proxy[_txid].requiredCount > 0);
		_;
	}
	modifier only_when_no_proxy(bytes32 _txid)
	{
		assert(proxy[_txid].requiredCount == 0);
		_;
	}
	modifier only_when_proxy_undecided(bytes32 _txid)
	{ 
		require(proxy[_txid].status[clientOwner[msg.sender]] == Status.Undecided);
		_; 
	}
	modifier when_required(bytes32 _client)
	{
		require(client[_client].required);
		_;
	}
	modifier when_have_all_required
	{
		require(fork[proposedFork].requiredCount >= clientsRequired);
		_;
	}
	modifier when_changing_required(bytes32 _client, bool _r)
	{
		require(client[_client].required != _r);
		_;
	}
	modifier when_proxy_confirmed(bytes32 _txid)
	{
		require(proxy[_txid].requiredCount >= clientsRequired);
		_;
	}

	mapping (uint32 => Fork) public fork;
	mapping (bytes32 => Client) public client;
	mapping (address => bytes32) public clientOwner;
	mapping (bytes32 => Transaction) public proxy;

	uint32 public clientsRequired;
	uint32 public latestFork;
	uint32 public proposedFork;
	address public grandOwner = msg.sender;
}
