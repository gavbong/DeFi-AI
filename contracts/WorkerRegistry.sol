// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IWorkerRegistry.sol";

contract WorkerRegistry is IWorkerRegistry, Ownable {
    constructor() Ownable(msg.sender) {}

    mapping(address => Worker) private workers;

    function register(bytes32 pubkey, string calldata metadataURI) external override {
        require(workers[msg.sender].operator == address(0), "Already registered");
        workers[msg.sender] = Worker({
            operator: msg.sender,
            pubkey: pubkey,
            stake: 0,
            reputation: 0,
            active: true,
            metadataURI: metadataURI
        });
        emit WorkerRegistered(msg.sender, pubkey, metadataURI);
    }

    function setActive(bool active) external override {
        Worker storage w = workers[msg.sender];
        require(w.operator != address(0), "Not registered");
        w.active = active;
        emit WorkerStatusChanged(msg.sender, active);
    }

    function updateMetadata(string calldata metadataURI) external override {
        Worker storage w = workers[msg.sender];
        require(w.operator != address(0), "Not registered");
        w.metadataURI = metadataURI;
        emit WorkerMetadataUpdated(msg.sender, metadataURI);
    }

    function get(address operator) external view override returns (Worker memory) {
        return workers[operator];
    }
}
