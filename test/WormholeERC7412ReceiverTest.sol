// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "cannon-std/Cannon.sol";

import "../src/WormholeERC7412Receiver.sol";

contract WormholeERC7412ReceiverTest is Test {
    using Cannon for Vm;

		WormholeERC7412Receiver module;

    function setUp() public {
        module = WormholeERC7412Receiver(vm.getAddress("WormholeERC7412Receiver"));
    }

    function testInitialState() public view {
    }

		function testEmitsERC7412WhenNotFound() public {
			WormholeERC7412Receiver.CrossChainRequest[] memory dummyCcr = new WormholeERC7412Receiver.CrossChainRequest[](2);
			dummyCcr[0] = WormholeERC7412Receiver.CrossChainRequest(13370, 1234, address(module), bytes("0x12345678"));
			dummyCcr[1] = WormholeERC7412Receiver.CrossChainRequest(31337, 2345, address(module), bytes("0x09876543"));

			vm.expectRevert(abi.encodeWithSelector(IERC7412.OracleDataRequired.selector, address(module), bytes("")));
			module.getCrossChainData(dummyCcr, 0);
		}

		function testCanFullfill() public {
			// fullfill a fake request
			bytes memory requestData = abi.encodePacked(
				uint32(4), // blockIdLength
				uint32(12341234), // blockid
				uint8(1), // numBatchCallData
				address(module), // call to address
				uint32(4), // call data length
				bytes4(0x12345678) // the call data
			);

			bytes memory responseData = abi.encodePacked(
					uint64(2424), // blockNum
					uint256(82828), // blockHash
					uint64(1111), // blockTime
					uint8(1), // numBatchResponseData
					uint32(32), // response length
					bytes32("RESPONSE")
			);

			bytes memory requestInfoBlock = abi.encodePacked(

				uint256(4321), // requestId
				uint32(requestData.length + 1 + 4 + 1 + 2 + 1 + 4), // queryRequestLength
				uint8(1), // response version
				uint32(100), // nonce
				uint8(1) // numPerChainQueries
					);

			bytes memory fakeResponse = abi.encodePacked(
				uint8(1), // version
				uint16(31337), // senderChainId

				// request info
				requestInfoBlock,

				// 1st request
				uint16(31337), // reqChainId
				uint8(1), // reqQueryType
				uint32(requestData.length), // request length
				requestData, // request data

				// response info
				uint8(1), // numPerchainResponses

				// 1st response
				uint16(31337), // reqChainId
				uint8(1), // reqQueryType
				uint32(responseData.length), // request length
				responseData
			);

			IWormhole.Signature[] memory sigs = new IWormhole.Signature[](1);

			string memory mnemonic = "test test test test test test test test test test test junk";
			uint256 privateKey = vm.deriveKey(mnemonic, 0);
			(sigs[0].v, sigs[0].r, sigs[0].s) = vm.sign(privateKey, keccak256(fakeResponse));

			module.fulfillOracleQuery(abi.encode(fakeResponse, sigs));

			WormholeERC7412Receiver.CrossChainRequest[] memory dummyCcr = new WormholeERC7412Receiver.CrossChainRequest[](1);
			dummyCcr[0] = WormholeERC7412Receiver.CrossChainRequest(31337, 1234, address(module), bytes("0x12345678"));

			bytes[] memory result = module.getCrossChainData(dummyCcr, 0);
			require(result[0].length == 32, "cross chain data incorrect");
		}
}
