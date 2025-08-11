import express from "express";
import cors from "cors";
import * as dotenv from "dotenv";
import { ethers } from "ethers";
import { tokenAbi, stakingAbi, marketAbi } from "./abi";

dotenv.config();

const {
  RPC_URL = "http://127.0.0.1:8545",
  PRIVATE_KEY,
  TOKEN,
  STAKING,
  MARKET,
  TREASURY,
  PORT = "3001",
} = process.env;

const app = express();
app.use(cors({ origin: true, methods: ["GET","POST","OPTIONS"], allowedHeaders: ["content-type"] }));
app.options("*", cors({ origin: true }));
app.use(express.json({ limit: "1mb" }));

// Validate env addresses EARLY (no ENS)
// If a value is missing/invalid, print a clear message and exit.
function mustAddr(v: string | undefined, name: string): string {
  if (!v) {
    console.error(`ENV ERROR: ${name} missing in .env`);
    process.exit(1);
  }
  if (!ethers.isAddress(v)) {
    console.error(`ENV ERROR: ${name} is not a valid 0x address: ${v}`);
    process.exit(1);
  }
  return v;
}
const TOKEN_ADDR   = mustAddr(TOKEN,   "TOKEN");
const STAKING_ADDR = mustAddr(STAKING, "STAKING");
const MARKET_ADDR  = mustAddr(MARKET,  "MARKET");

// Provider (fine to create at startup)
const provider = new ethers.JsonRpcProvider(RPC_URL);

// Lazily create signer + contracts per request
function getSigner(fromPrivateKey?: string) {
  const pk = fromPrivateKey ?? PRIVATE_KEY;
  if (!pk) throw new Error("No PRIVATE_KEY provided (env or body.fromPrivateKey)");
  return new ethers.Wallet(pk, provider);
}
function getContracts(fromPrivateKey?: string) {
  const signer = getSigner(fromPrivateKey);
  return {
    signer,
    token:   new ethers.Contract(TOKEN_ADDR,   tokenAbi,  signer),
    staking: new ethers.Contract(STAKING_ADDR, stakingAbi, signer),
    market:  new ethers.Contract(MARKET_ADDR,  marketAbi, signer),
  };
}

app.get("/health", (_req, res) => res.json({ ok: true }));
app.get("/addresses", (_req, res) =>
  res.json({ TOKEN: TOKEN_ADDR, STAKING: STAKING_ADDR, MARKET: MARKET_ADDR, TREASURY })
);

app.post("/stake", async (req, res) => {
  try {
    const { amount, fromPrivateKey } = req.body;
    if (!amount) return res.status(400).json({ error: "amount required" });
    const { token, staking, signer } = getContracts(fromPrivateKey);
    const wei = ethers.parseUnits(String(amount), 18);
    const tx1 = await token.approve(await staking.getAddress(), wei);
    await tx1.wait();
    const tx2 = await staking.stake(wei);
    const rc = await tx2.wait();
    res.json({ from: await signer.getAddress(), tx: tx2.hash, receipt: rc });
  } catch (e: any) { res.status(500).json({ error: e?.message || String(e) }); }
});

app.post("/postJob", async (req, res) => {
  try {
    const { budget, quorum, deadline, specURI, fromPrivateKey } = req.body;
    if (!budget || !quorum || !deadline || !specURI)
      return res.status(400).json({ error: "budget, quorum, deadline, specURI required" });

    const { token, market, signer } = getContracts(fromPrivateKey);
    const wei = ethers.parseUnits(String(budget), 18);

    const tx1 = await token.approve(await market.getAddress(), wei);
    await tx1.wait();

    const tx2 = await market.postJob(wei, Number(quorum), Number(deadline), String(specURI));
    const rc = await tx2.wait();
    const jobId = await market.jobCounter();

    res.json({ from: await signer.getAddress(), tx: tx2.hash, jobId: jobId.toString(), receipt: rc });
  } catch (e: any) { res.status(500).json({ error: e?.message || String(e) }); }
});

app.post("/submit", async (req, res) => {
  try {
    const { jobId, resultURI, resultHash, fromPrivateKey } = req.body;
    if (jobId === undefined || !resultURI || !resultHash)
      return res.status(400).json({ error: "jobId, resultURI, resultHash required" });

    const { market, signer } = getContracts(fromPrivateKey);
    const tx = await market.submit(BigInt(jobId), String(resultURI), resultHash);
    const rc = await tx.wait();
    res.json({ from: await signer.getAddress(), tx: tx.hash, receipt: rc });
  } catch (e: any) { res.status(500).json({ error: e?.message || String(e) }); }
});

app.post("/settle", async (req, res) => {
  try {
    const { jobId, resultHash, winners, payouts, fromPrivateKey } = req.body;
    if (jobId === undefined || !resultHash || !Array.isArray(winners) || !Array.isArray(payouts))
      return res.status(400).json({ error: "jobId, resultHash, winners[], payouts[] required" });

    const { market, signer } = getContracts(fromPrivateKey);
    const payoutsWei = payouts.map((p: any) => ethers.parseUnits(String(p), 18));
    const tx = await market.settleAgreed(BigInt(jobId), resultHash, winners, payoutsWei);
    const rc = await tx.wait();
    res.json({ from: await signer.getAddress(), tx: tx.hash, receipt: rc });
  } catch (e: any) { res.status(500).json({ error: e?.message || String(e) }); }
});

app.listen(Number(PORT), () => {
  console.log(`gateway listening on http://127.0.0.1:${PORT}`);
});
