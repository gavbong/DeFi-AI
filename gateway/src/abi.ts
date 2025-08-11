export const tokenAbi = [
  "function approve(address spender, uint256 value) external returns (bool)",
  "function balanceOf(address) view returns (uint256)",
  "function mint(address to, uint256 amount) external",
];

export const stakingAbi = [
  "function stake(uint256 amount) external",
  "function stakes(address who) view returns (uint256 amount, uint256 unlockAt)"
];

export const marketAbi = [
  "function postJob(uint256 budget, uint8 quorum, uint64 deadline, string specURI) external returns (uint256)",
  "function submit(uint256 jobId, string resultURI, bytes32 resultHash) external",
  "function settleAgreed(uint256 jobId, bytes32 agreedHash, address[] winners, uint256[] payouts) external",
  "function jobCounter() view returns (uint256)"
];
