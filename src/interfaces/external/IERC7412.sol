// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface IERC7412 {
  error FeeRequired(uint amount);
  error OracleDataRequired(address oracleContract, bytes oracleQuery);

  function oracleId() view external returns (bytes32 oracleId);
  function fulfillOracleQuery(bytes calldata signedOffchainData) payable external;
}
