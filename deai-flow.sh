#!/usr/bin/env bash
set -euo pipefail

# ------------ config ------------
GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:3002}"
RPC="${RPC:-http://127.0.0.1:8545}"

# Anvil defaults
CLIENT_ADDR="${CLIENT_ADDR:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}" # anvil #2
CLIENT_PK="${CLIENT_PK:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
WORKER_ADDR="${WORKER_ADDR:-0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC}" # anvil #3
WORKER_PK="${WORKER_PK:-0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a}"

BUDGET="${BUDGET:-100}"       # DEAI
STAKE_AMT="${STAKE_AMT:-100}" # DEAI
PAYOUT="${PAYOUT:-97}"        # DEAI to worker
RESULT_URI="${RESULT_URI:-ipfs://result}"
RESULT_HASH="${RESULT_HASH:-0x0000000000000000000000000000000000000000000000000000000000001234}"
QUORUM="${QUORUM:-1}"
DEADLINE="$(($(date +%s) + 3600))"

# CSV output file
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV="${CSV:-deai-run-$STAMP.csv}"

# ------------ helpers ------------
have() { command -v "$1" >/dev/null 2>&1; }
jget() {  # jq or naive grep fallback
  if have jq; then jq -r "$2" <<<"$1"; else
    grep -o "\"$3\":\"0x[^\"]\+\"" <<<"$1" | head -n1 | cut -d'"' -f4
  fi
}

wei_to_token() {  # human display (approx) — prints decimal tokens from wei
  awk -v v="$1" 'BEGIN{printf "%.4f", v/1e18}'
}

get_bal() {  # reads ERC20 balanceOf(address) from TOKEN using cast
  local addr="$1"
  cast call "$TOKEN" "balanceOf(address)(uint256)" "$addr" --rpc-url "$RPC"
}

step() { echo -e "\n=== $* ==="; }

write_csv_header() {
  if [ ! -f "$CSV" ]; then
    echo "timestamp,token,client_before_wei,client_after_wei,client_delta_wei,worker_before_wei,worker_after_wei,worker_delta_wei,treasury_before_wei,treasury_after_wei,treasury_delta_wei,job_id,budget_deai,payout_deai" > "$CSV"
  fi
}

append_csv_row() {
  local ts="$1" tok="$2" cb="$3" ca="$4" cd="$5" wb="$6" wa="$7" wd="$8" tb="$9" ta="${10}" td="${11}" jid="${12}" bud="${13}" pay="${14}"
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" "$ts" "$tok" "$cb" "$ca" "$cd" "$wb" "$wa" "$wd" "$tb" "$ta" "$td" "$jid" "$bud" "$pay" >> "$CSV"
}

# ------------ start ------------
step "Gateway health @ $GATEWAY_URL"
curl -s "$GATEWAY_URL/health" | cat

step "Fetch contract addresses from gateway"
ADDR_JSON="$(curl -s "$GATEWAY_URL/addresses")"
echo "$ADDR_JSON" | (have jq && jq . || cat)

# Extract TOKEN / TREASURY
if have jq; then
  TOKEN=$(jget "$ADDR_JSON" '.TOKEN' TOKEN)
  TREASURY=$(jget "$ADDR_JSON" '.TREASURY' TREASURY)
else
  TOKEN=$(jget "$ADDR_JSON" '' TOKEN)
  TREASURY=$(jget "$ADDR_JSON" '' TREASURY)
fi

if [[ -z "${TOKEN:-}" || "${TOKEN:0:2}" != "0x" ]]; then
  echo "ERROR: Could not read TOKEN address from gateway /addresses"
  exit 1
fi
echo "TOKEN=$TOKEN"
echo "TREASURY=${TREASURY:-<none provided>}"

if ! have cast; then
  echo "WARN: foundry 'cast' not installed — skipping balance checks."
fi

# ------------ balances BEFORE ------------
if have cast; then
  step "Balances BEFORE"
  C_BEFORE="$(get_bal "$CLIENT_ADDR")"
  W_BEFORE="$(get_bal "$WORKER_ADDR")"
  if [[ -n "${TREASURY:-}" && "${TREASURY:0:2}" == "0x" ]]; then
    T_BEFORE="$(get_bal "$TREASURY")"
  else
    T_BEFORE="0"
  fi
  echo "Client:   $(wei_to_token "$C_BEFORE") DEAI  (wei=$C_BEFORE)"
  echo "Worker:   $(wei_to_token "$W_BEFORE") DEAI  (wei=$W_BEFORE)"
  echo "Treasury: $(wei_to_token "$T_BEFORE") DEAI  (wei=$T_BEFORE)"
fi

# ------------ 1) Stake ------------
step "Stake $STAKE_AMT DEAI as WORKER"
curl -s -X POST "$GATEWAY_URL/stake" \
  -H "content-type: application/json" \
  -d "{\"amount\":\"$STAKE_AMT\",\"fromPrivateKey\":\"$WORKER_PK\"}" | (have jq && jq . || cat)

# ------------ 2) Post Job ------------
step "Post Job: budget=$BUDGET quorum=$QUORUM deadline=$DEADLINE specURI=$RESULT_URI"
POST_RESP="$(curl -s -X POST "$GATEWAY_URL/postJob" \
  -H "content-type: application/json" \
  -d "{\"budget\":\"$BUDGET\",\"quorum\":$QUORUM,\"deadline\":$DEADLINE,\"specURI\":\"ipfs://spec\",\"fromPrivateKey\":\"$CLIENT_PK\"}")"
echo "$POST_RESP" | (have jq && jq . || cat)

if have jq; then
  JOBID="$(echo "$POST_RESP" | jq -r '.jobId // "1"')"
else
  JOBID="$(echo "$POST_RESP" | sed -n 's/.*"jobId":"\([0-9]\+\)".*/\1/p')"; JOBID="${JOBID:-1}"
fi
step "Using jobId=$JOBID"

# ------------ 3) Submit ------------
step "Submit result for jobId=$JOBID"
curl -s -X POST "$GATEWAY_URL/submit" \
  -H "content-type: application/json" \
  -d "{\"jobId\":$JOBID,\"resultURI\":\"$RESULT_URI\",\"resultHash\":\"$RESULT_HASH\",\"fromPrivateKey\":\"$WORKER_PK\"}" | (have jq && jq . || cat)

# ------------ 4) Settle ------------
step "Settle agreed: pay $PAYOUT DEAI to $WORKER_ADDR"
curl -s -X POST "$GATEWAY_URL/settle" \
  -H "content-type: application/json" \
  -d "{\"jobId\":$JOBID,\"resultHash\":\"$RESULT_HASH\",\"winners\":[\"$WORKER_ADDR\"],\"payouts\":[\"$PAYOUT\"],\"fromPrivateKey\":\"$CLIENT_PK\"}" | (have jq && jq . || cat)

# ------------ balances AFTER + CSV ------------
if have cast; then
  step "Balances AFTER"
  C_AFTER="$(get_bal "$CLIENT_ADDR")"
  W_AFTER="$(get_bal "$WORKER_ADDR")"
  if [[ -n "${TREASURY:-}" && "${TREASURY:0:2}" == "0x" ]]; then
    T_AFTER="$(get_bal "$TREASURY")"
  else
    T_AFTER="0"
  fi

  echo "Client:   $(wei_to_token "$C_AFTER") DEAI  (wei=$C_AFTER)"
  echo "Worker:   $(wei_to_token "$W_AFTER") DEAI  (wei=$W_AFTER)"
  echo "Treasury: $(wei_to_token "$T_AFTER") DEAI  (wei=$T_AFTER)"

  # Δ (in wei; display tokens approx)
  C_DELTA="$(expr "$C_AFTER" - "${C_BEFORE:-0}")"
  W_DELTA="$(expr "$W_AFTER" - "${W_BEFORE:-0}")"
  T_DELTA="$(expr "$T_AFTER" - "${T_BEFORE:-0}")"

  step "Δ Balances (After - Before)"
  echo "Client Δ:   $(wei_to_token "$C_DELTA") DEAI  (wei=$C_DELTA)"
  echo "Worker Δ:   $(wei_to_token "$W_DELTA") DEAI  (wei=$W_DELTA)"
  echo "Treasury Δ: $(wei_to_token "$T_DELTA") DEAI  (wei=$T_DELTA)"

  # Write CSV
  write_csv_header
  append_csv_row "$STAMP" "$TOKEN" "$C_BEFORE" "$C_AFTER" "$C_DELTA" "$W_BEFORE" "$W_AFTER" "$W_DELTA" "$T_BEFORE" "$T_AFTER" "$T_DELTA" "$JOBID" "$BUDGET" "$PAYOUT"
  echo -e "\nCSV written to: $CSV"
else
  echo "NOTE: Install Foundry (cast) to enable balance snapshots & CSV."
fi

step "Done ✅"
