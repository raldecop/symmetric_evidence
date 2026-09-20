# Symmetric Cross-Chain Evidence Protocol — Verifpal Models

This directory contains the Verifpal models used for the cryptographic analysis of the Symmetric Cross-Chain Evidence Protocol.

The models were designed for Verifpal 1.4.12 and were evaluated from the command line with one, two, and three concurrent sessions per principal.

## Files

- `01_symmetric_evidence_full.vp` — complete cryptographic abstraction with 11 queries: 2 confidentiality, 4 authentication, 2 freshness, and 3 equivalence queries.
- `02_authentication.vp` — targeted model containing the four authentication queries.
- `03_session_freshness.vp` — targeted model for session freshness and session correspondence.
- `04_ack_binding.vp` — targeted model for commitment–acknowledgment binding and return-path correspondence.
- `05_negative_no_fresh_nonce.vp` — negative-control model in which only the fresh sender nonce `nA` is removed from `sid`.
- `check_models.sh` — parses all `.vp` files using Verifpal and reports syntax/model-loading errors.
- `run_all.sh` — runs all five models with 1, 2, and 3 sessions and stores terminal output and compact result codes under `results/`.

## Verification boundary

The Verifpal models analyze the cryptographic message layer under an active Dolev–Yao attacker.

The following modeling choices are intentional:

1. `protocolContext` is a public atomic abstraction of the canonical ordered encoding `Encode(domain, B1, B2, SC1, SC2)`. 
2. Protocol objects are represented at the field level to keep the symbolic search tractable while preserving the cryptographic dependencies.
3. `[pkA]` and `[pkB]` represent the assumed authentic binding between participant identities and their registered public keys.
4. `[d1]` and `[d2]` abstract successful external cross-chain evidence verification. They do not model consensus, finality, light clients, Merkle proofs or proof verification internally.
5. `[delivery]` models receiver `B` reading the commitment already accepted by `SC2` from authenticated `B2` state.
6. Persistent smart-contract state such as `state1[sid]` and `state2[sid]` is intentionally excluded from Verifpal and is analyzed separately in the state-machine model.
7. `completion` is only a Verifpal modeling event used as a query precondition. 

The conceptual protocol dependencies are:

- `M = (sid, m, A, B)`
- `sigA = Sign(skA, H(M))`
- `t1 = (M, sigA)`
- `d1 = H(t1)`
- `Ack = (sid, d1, NB)`
- `sigB = Sign(skB, H(Ack))`
- `t2 = (Ack, sigB)`
- `d2 = H(t2)`

The Verifpal field-level abstraction represents the same dependencies as:

- `sid = HASH(protocolContext, aid, bid, nA)`
- `H(M) = HASH(sid, m, aid, bid)`
- `t1 = CONCAT(sid, m, aid, bid, sigA)`
- `d1 = HASH(t1)`
- `H(Ack) = HASH(sid, d1, nB)`
- `t2 = CONCAT(sid, d1, nB, sigB)`
- `d2 = HASH(t2)`

## Requirements

Confirm that Verifpal is available:

```bash
verifpal --version
```

The experiments reported for the paper were run with Verifpal 1.4.10.

## 1. Parse/check the models

Run:

```bash
chmod +x check_models.sh
./check_models.sh
```

The script invokes `verifpal pretty MODEL.vp` for each file. `pretty` requires successful parsing and model loading; its formatted output is discarded.

To check one model manually:

```bash
verifpal pretty 01_symmetric_evidence_full.vp > /dev/null
```

## 2. Run a single verification

Always specify the number of sessions explicitly. Verifpal otherwise uses two sessions by default.

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 1 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 3 --color never
```

The same pattern applies to the other models.

## 3. Run all experiments

Run:

```bash
chmod +x run_all.sh
./run_all.sh
```

For every model and session count, the script creates:

- `results/<model>_s<sessions>.log` — complete terminal output.
- `results/<model>_s<sessions>.code` — compact Verifpal result code.

The script intentionally does **not** use `--fail-on-attack`, because some failed queries are expected experimental results rather than execution errors.

## Expected results

### 01 — Full model

With **1 session**, all 11 queries pass.

With **2 sessions**, exactly two queries fail:

```text
authentication? Sender -> Sc1: t1[precondition[Sc1 -> Sender: completion]]
authentication? Receiver -> Sc2: t2[precondition[Sc1 -> Sender: completion]]
```

Verifpal classifies both as:

```text
duplicate acceptance: no recipient-generated context
```

The remaining 9 queries pass.

With **3 sessions**, the result is identical: the same two authentication queries fail and the remaining 9 queries pass.

### 02 — Authentication model

With **1 session**, all authentication queries pass.

With **2 and 3 sessions**, the same two queries fail:

- authentication of `t1` at `SC1`;
- authentication of `t2` at `SC2`.

The authentication queries for `d1` and `d2` pass.

Both failures are classified as:

```text
duplicate acceptance: no recipient-generated context
```

### 03 — Session freshness model

No query fails with **1, 2, or 3 sessions**.

This confirms that the modeled session freshness and session correspondence remain satisfied under the tested session bounds.

### 04 — Acknowledgment-binding model

No query fails with **1, 2, or 3 sessions**.

This confirms that the modeled commitment–acknowledgment and return-path bindings remain satisfied under the tested session bounds.

### 05 — Negative freshness control

The query

```text
freshness? sid[precondition[Sc1 -> Sender: completion]]
```

fails with **1, 2, and 3 sessions**.

The freshness query for `hAckB = H(Ack)` continues to pass.

The only relevant change is the session identifier:

Positive model:

```text
sid = HASH(protocolContext, aid, bid, nA)
```

Negative control:

```text
sid = HASH(protocolContext, aid, bid)
```

Thus, the experiment isolates the contribution of the fresh sender nonce `nA`.

## Interpretation

The concurrent-session failures in Models 01 and 02 do not represent signature forgery or a broken commitment–acknowledgment binding. They represent replay of an already cryptographically valid `t1` or `t2`.

Because the Verifpal abstraction intentionally omits persistent recipient state, it has no state variable recording that the corresponding `sid` has already produced the relevant protocol transition. The same valid object can therefore be accepted again.

The experimental result motivates the distinction:

```text
Fresh(sid) AND CryptographicallyValid(t)
    does not imply
AcceptOnce(t)
```

Replay-resistant acceptance is analyzed separately through the persistent contract state machine.

## Optional structured reports

JSON:

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never --format json > full_s2.json
```

HTML:

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never --format html > full_s2.html
```

LaTeX:

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never --format tex > full_s2.tex
```

## Important interpretation note

A passing query means that Verifpal found no contradiction within the analyzed model, assumptions, search limits, and selected session count. The experiments with one, two, and three sessions do not constitute an unbounded proof for an arbitrary number of concurrent executions.
