// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStaking.sol";

contract Marketplace is ReentrancyGuard, Pausable, Ownable {
    struct Job {
        address client;
        uint256 budget;
        string specURI;
        uint8 quorum;
        uint64 deadline;
        bool settled;
        bool disputed;
    }

    struct Submission { address worker; string resultURI; bytes32 resultHash; }

    IERC20 public immutable token;
    IStaking public staking;
    address public treasury;
    address public arbitrator;

    uint256 public feeBps = 300; // 3%
    uint256 public minWorkerStake = 100e18;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Submission[]) public submissions;
    uint256 public jobCounter;

    event JobPosted(uint256 indexed jobId, address indexed client, uint256 budget, uint8 quorum, uint64 deadline, string specURI);
    event Submitted(uint256 indexed jobId, address indexed worker, string resultURI, bytes32 resultHash);
    event Settled(uint256 indexed jobId, address[] winners, uint256[] payouts, uint256 fee);
    event Disputed(uint256 indexed jobId, string reason);
    event DisputeResolved(uint256 indexed jobId, address[] recipients, uint256[] payouts, uint256 fee);

    modifier onlyArbitrator() { require(msg.sender == arbitrator, "not arbitrator"); _; }

    constructor(IERC20 token_, address staking_, address treasury_, address arbitrator_)
        Ownable(msg.sender)
    {
        token = token_;
        staking = IStaking(staking_);
        treasury = treasury_;
        arbitrator = arbitrator_;
    }

    function setFee(uint256 newFeeBps) external onlyOwner { require(newFeeBps <= 1000, "fee too high"); feeBps = newFeeBps; }
    function setArbitrator(address a) external onlyOwner { arbitrator = a; }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function postJob(uint256 budget, uint8 quorum, uint64 deadline, string calldata specURI) external whenNotPaused nonReentrant returns (uint256) {
        require(quorum >= 1 && quorum <= 5, "bad quorum");
        require(deadline > block.timestamp + 5 minutes, "deadline soon");
        token.transferFrom(msg.sender, address(this), budget);
        uint256 id = ++jobCounter;
        jobs[id] = Job({ client: msg.sender, budget: budget, specURI: specURI, quorum: quorum, deadline: deadline, settled: false, disputed: false });
        emit JobPosted(id, msg.sender, budget, quorum, deadline, specURI);
        return id;
    }

    function submit(uint256 jobId, string calldata resultURI, bytes32 resultHash) external whenNotPaused nonReentrant {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "no job");
        require(block.timestamp <= j.deadline, "deadline passed");
        (uint256 amount,) = staking.stakes(msg.sender);
        require(amount >= minWorkerStake, "stake low");
        submissions[jobId].push(Submission({worker: msg.sender, resultURI: resultURI, resultHash: resultHash}));
        emit Submitted(jobId, msg.sender, resultURI, resultHash);
    }

    function settleAgreed(uint256 jobId, bytes32 /*agreedHash*/, address[] calldata winners, uint256[] calldata payouts) external nonReentrant {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client, "not client");
        require(!j.settled && !j.disputed, "closed");
        require(winners.length == payouts.length && winners.length > 0, "bad arrays");

        uint256 fee = (j.budget * feeBps) / 10000;
        uint256 total = 0; for (uint256 i=0; i<payouts.length; i++) total += payouts[i];
        require(total + fee <= j.budget, "exceeds budget");

        for (uint256 i=0; i<winners.length; i++) {
            token.transfer(winners[i], payouts[i]);
        }
        token.transfer(treasury, fee);
        j.settled = true;
        emit Settled(jobId, winners, payouts, fee);
    }

    function openDispute(uint256 jobId, string calldata reason) external nonReentrant {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client, "not client");
        require(!j.settled && !j.disputed, "closed");
        j.disputed = true;
        emit Disputed(jobId, reason);
    }

    function resolveDispute(uint256 jobId, address[] calldata recipients, uint256[] calldata payouts) external onlyArbitrator nonReentrant {
        Job storage j = jobs[jobId];
        require(j.disputed && !j.settled, "not disputed");
        require(recipients.length == payouts.length && recipients.length > 0, "bad arrays");

        uint256 fee = (j.budget * feeBps) / 10000;
        uint256 total = 0; for (uint256 i=0; i<payouts.length; i++) total += payouts[i];
        require(total + fee <= j.budget, "exceeds budget");

        for (uint256 i=0; i<recipients.length; i++) {
            token.transfer(recipients[i], payouts[i]);
        }
        token.transfer(treasury, fee);
        j.settled = true; j.disputed = false;
        emit DisputeResolved(jobId, recipients, payouts, fee);
    }
}
