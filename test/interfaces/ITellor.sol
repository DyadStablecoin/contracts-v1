pragma solidity ^0.8.0;

interface ITellor {
    function balanceOf(address) external view returns (uint256);
    function submitValue(bytes32 _queryId, bytes calldata _value, uint256 _nonce, bytes memory _queryData) external;
    function depositStake(uint256 _amount) external;
}