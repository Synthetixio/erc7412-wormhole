// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// TODO: Import via npm after next release
import "./lib/WormholeQueryResponse.sol";
import "./interfaces/external/IERC7412.sol";

contract WormholeERC7412Receiver is WormholeQueryResponse, IERC7412 {
    address public immutable wormholeAddress;

		mapping (bytes32 => uint256) public queryResponseTimes;
		mapping (bytes32 => bytes) public queryResponses;

		struct CrossChainRequest {
			uint64 chainSelector;
			uint256 timestamp;
			address target;
			bytes data;
		}

    constructor(address _wormholeAddress) {
        wormholeAddress = _wormholeAddress;
    }

    function oracleId() pure external returns (bytes32) {
        return bytes32("WORMHOLE");
    }

		function getCrossChainData(CrossChainRequest[] memory reqs, uint256 maxAge) external view returns (bytes[] memory) {
			CrossChainRequest[] memory oracleDataRequired = new CrossChainRequest[](reqs.length);
			uint256 odrCount = 0;

			bytes[] memory responses = new bytes[](reqs.length);

			for (uint i = 0;i < reqs.length;i++) {
				CrossChainRequest memory req = reqs[i];
				bytes32 reqHash = keccak256(abi.encodePacked(req.chainSelector, req.target, req.data));

				if ((maxAge == 0 && queryResponseTimes[reqHash] != req.timestamp) || (maxAge != 0 && queryResponseTimes[reqHash] < req.timestamp - maxAge)) {
					oracleDataRequired[odrCount++] = req;
				}

				else if (odrCount == 0) {
					responses[i] = queryResponses[reqHash];
				}
			}

			if (odrCount > 0) {
				// use an assembly trick to shorten the length of the array before we revert it
				// (why solidity still cant do this is something only the establishment solidity devs can answer for lol)
				assembly { mstore(oracleDataRequired, odrCount) }

				revert OracleDataRequired(address(this), abi.encode(oracleDataRequired));
			}

			return responses;
		}

    function fulfillOracleQuery(bytes memory signedOffchainData) payable external {
			(bytes memory response, IWormhole.Signature[] memory sigs) = abi.decode(signedOffchainData, (bytes, IWormhole.Signature[]));
			ParsedQueryResponse memory pqr = parseAndVerifyQueryResponse(wormholeAddress, response, sigs);

			for (uint i = 0;i < pqr.responses.length;i++) {
				ParsedPerChainQueryResponse memory pcr = pqr.responses[i];
				EthCallQueryResponse memory ecr = parseEthCallQueryResponse(pcr);

				for (uint j = 0;j < ecr.result.length;j++) {
					EthCallData memory ecd = ecr.result[j];

					bytes32 reqHash = keccak256(abi.encodePacked(pcr.chainId, ecd.contractAddress, ecd.callData));
					queryResponses[reqHash] = ecd.result;
					queryResponseTimes[reqHash] = ecr.blockTime;
				}
			}
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC7412).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
