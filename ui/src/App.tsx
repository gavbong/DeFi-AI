import { useMemo, useState } from "react";

const GATEWAY = import.meta.env.VITE_GATEWAY_URL || "http://127.0.0.1:3002";

type Json = any;

async function post(path: string, body: object): Promise<Json> {
  const r = await fetch(`${GATEWAY}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await r.text();
  try { return JSON.parse(text); } catch { return { raw: text, status: r.status }; }
}

function useNowPlusHour() {
  return useMemo(() => Math.floor(Date.now() / 1000) + 3600, []);
}

export default function App() {
  const [resp, setResp] = useState<Json | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Keys (defaults = Anvil)
  const [clientPk, setClientPk] = useState("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d");
  const [workerPk, setWorkerPk] = useState("0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a");
  const [workerAddr, setWorkerAddr] = useState("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC");

  // Stake
  const [stakeAmt, setStakeAmt] = useState("100");

  // Post job
  const [budget, setBudget] = useState("100");
  const [quorum, setQuorum] = useState(1);
  const [specURI, setSpecURI] = useState("ipfs://spec");
  const deadline = useNowPlusHour();

  // Submit
  const [jobId, setJobId] = useState<number>(1);
  const [resultURI, setResultURI] = useState("ipfs://result");
  const [resultHash, setResultHash] = useState("0x0000000000000000000000000000000000000000000000000000000000001234");

  // Settle
  const [payout, setPayout] = useState("97");

  // loading flags to prevent double-clicks
  const [staking, setStaking] = useState(false);
  const [posting, setPosting] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [settling, setSettling] = useState(false);

  function show(o: Json) { setError(null); setResp(o); }
  function fail(e: any) { setResp(null); setError(e?.error || e?.message || String(e)); }

  const doStake = async () => {
    if (staking) return;
    setStaking(true);
    try { show(await post("/stake", { amount: stakeAmt, fromPrivateKey: workerPk })); }
    catch (e:any) { fail(e); }
    finally { setStaking(false); }
  };

  const doPostJob = async () => {
    if (posting) return;
    setPosting(true);
    try {
      const out = await post("/postJob", { budget, quorum, deadline, specURI, fromPrivateKey: clientPk });
      show(out);
      const maybeId = Number(out?.jobId);
      if (!Number.isNaN(maybeId) && maybeId > 0) setJobId(maybeId);
    } catch (e:any) { fail(e); }
    finally { setPosting(false); }
  };

  const doSubmit = async () => {
    if (submitting) return;
    setSubmitting(true);
    try { show(await post("/submit", { jobId, resultURI, resultHash, fromPrivateKey: workerPk })); }
    catch (e:any) { fail(e); }
    finally { setSubmitting(false); }
  };

  const doSettle = async () => {
    if (settling) return;
    setSettling(true);
    try {
      show(await post("/settle", {
        jobId, resultHash, winners: [workerAddr], payouts: [payout], fromPrivateKey: clientPk
      }));
    } catch (e:any) { fail(e); }
    finally { setSettling(false); }
  };

  return (
    <div style={{ fontFamily: "Inter, system-ui, sans-serif", maxWidth: 980, margin: "24px auto", padding: 16 }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>DeAI MVP — Control Panel</h1>
      <p style={{ color: "#555", marginBottom: 24 }}>
        Gateway: <code>{GATEWAY}</code>
      </p>

      <section style={{ display: "grid", gap: 16, gridTemplateColumns: "1fr 1fr" }}>
        <Card title="Keys (Anvil defaults)">
          <Label>Client Private Key</Label>
          <Input value={clientPk} onChange={e=>setClientPk(e.target.value)} />
          <Label>Worker Private Key</Label>
          <Input value={workerPk} onChange={e=>setWorkerPk(e.target.value)} />
          <Label>Worker Address</Label>
          <Input value={workerAddr} onChange={e=>setWorkerAddr(e.target.value)} />
        </Card>

        <Card title="Stake (worker)">
          <Label>Amount (DEAI)</Label>
          <Input value={stakeAmt} onChange={e=>setStakeAmt(e.target.value)} />
          <Button onClick={doStake} disabled={staking}>
            {staking ? "Staking…" : "Stake"}
          </Button>
        </Card>

        <Card title="Post Job (client)">
          <Label>Budget (DEAI)</Label>
          <Input value={budget} onChange={e=>setBudget(e.target.value)} />
          <Label>Quorum</Label>
          <Input type="number" value={quorum} onChange={e=>setQuorum(parseInt(e.target.value||"1"))} />
          <Label>Deadline (epoch sec)</Label>
          <Input value={deadline} readOnly />
          <Label>Spec URI</Label>
          <Input value={specURI} onChange={e=>setSpecURI(e.target.value)} />
          <Button onClick={doPostJob} disabled={posting}>
            {posting ? "Posting…" : "Post Job"}
          </Button>
        </Card>

        <Card title="Submit Result (worker)">
          <Label>Job ID</Label>
          <Input type="number" value={jobId} onChange={e=>setJobId(parseInt(e.target.value||"1"))} />
          <Label>Result URI</Label>
          <Input value={resultURI} onChange={e=>setResultURI(e.target.value)} />
          <Label>Result Hash (bytes32)</Label>
          <Input value={resultHash} onChange={e=>setResultHash(e.target.value)} />
          <Button onClick={doSubmit} disabled={submitting}>
            {submitting ? "Submitting…" : "Submit"}
          </Button>
        </Card>

        <Card title="Settle (client)">
          <Label>Payout to Worker (DEAI)</Label>
          <Input value={payout} onChange={e=>setPayout(e.target.value)} />
          <Button onClick={doSettle} disabled={settling}>
            {settling ? "Settling…" : "Settle Agreed"}
          </Button>
        </Card>
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 20, marginBottom: 8 }}>Response</h2>
        <pre style={{ background: "#0b1021", color: "#cbe5ff", padding: 12, borderRadius: 8, overflowX: "auto" }}>
{JSON.stringify(resp ?? (error ? { error } : { note: "Actions will show JSON responses here." }), null, 2)}
        </pre>
      </section>
    </div>
  );
}

function Card({ title, children }: { title: string, children: any }) {
  return (
    <div style={{ border: "1px solid #e5e7eb", borderRadius: 12, padding: 16, background: "#fff" }}>
      <div style={{ fontWeight: 600, marginBottom: 12 }}>{title}</div>
      <div style={{ display: "grid", gap: 8 }}>{children}</div>
    </div>
  );
}
function Label({ children }: { children: any }) {
  return <label style={{ fontSize: 12, color: "#555" }}>{children}</label>;
}
function Input(props: any) {
  return <input {...props} style={{ padding: 8, borderRadius: 8, border: "1px solid #e5e7eb" }} />;
}
function Button({ children, ...props }: any) {
  return <button {...props} style={{ padding: "10px 12px", borderRadius: 10, border: 0, background: "#111827", color: "#fff", cursor: "pointer" }}>{children}</button>;
}
