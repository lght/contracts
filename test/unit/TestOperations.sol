import "truffle/Assertions.sol";
import "../../contracts/Operations.sol";

contract TestOperations {
	function testInitializationNew() {
		Operations ops = new Operations();

		var _track = uint8(1);
		var _client = bytes32("parity");
		var release = ops.latestInTrack(_client, _track);

		ClientTrackRelease(_client, _track, release);

		assert(release.length > 0);
	}

	event ClientTrackRelease(bytes32 _client, uint8 _track, bytes32 _release);
}
