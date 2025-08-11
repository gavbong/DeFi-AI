// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IWorkerRegistry {
    struct Worker {
        address operator;
        bytes32 pubkey;
        uint96 stake;
        uint32 reputation;
        bool active;
        string metadataURI;
    }

    event WorkerRegistered(address indexed operator, bytes32 pubkey, string metadataURI);
    event WorkerStatusChanged(address indexed operator, bool active);
    event WorkerMetadataUpdated(address indexed operator, string metadataURI);

    function register(bytes32 pubkey, string calldata metadataURI) external;
    function setActive(bool active) external;
    function updateMetadata(string calldata metadataURI) external;
    function get(address operator) external view returns (Worker memory);
}
