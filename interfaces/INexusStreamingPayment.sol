// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface INexusStreamingPayment {
    function createStream(address recipient, uint256 deposit, uint256 startTime, uint256 stopTime) external payable returns (uint256 streamId);
    function withdrawFromStream(uint256 streamId, uint256 funds) external;
    function cancelStream(uint256 streamId) external;
}
