# Symmetric Cross-Chain Evidence Protocol — Verifpal Specification

This repository contains the Verifpal models and supporting scripts used for the symbolic cryptographic analysis of the **Symmetric Cross-Chain Evidence Protocol**.

The models correspond to the protocol specification and verification boundary described in the paper *Symbolic Formalization and Verification of a Cryptographic Protocol for Symmetric Cross-Chain Evidence*.

## Repository contents

- `01_symmetric_evidence_full.vp` — complete cryptographic abstraction with 11 queries:
  - 2 confidentiality queries
  - 4 authentication queries
  - 2 freshness queries
  - 3 equivalence queries
- `02_authentication.vp` — targeted authentication model.
- `03_session_freshness.vp` — targeted session-freshness and session-correspondence model.
- `04_ack_binding.vp` — targeted commitment–acknowledgment and return-path binding model.
- `05_negative_no_fresh_nonce.vp` — negative control in which only the fresh sender nonce `nA` is removed from the session identifier.
- `check_models.sh` — parses all `.vp` files and reports syntax/model-loading errors.
- `run_all.sh` — executes all models with 1, 2, and 3 sessions and stores the results under `results/`.

## Requirements

The analysis reported in the paper uses:

```text
Verifpal 1.6.7
```

Check the installed version with:

```bash
verifpal --version
```

## Protocol specification represented by the models

### Execution context and session identifier

The concrete protocol defines:

```text
C = Encode(domain, B1, B2, SC1, SC2)
sid = H(C, A, B, NA)
```

where `NA` is a fresh sender nonce.

In Verifpal:

```text
protocolContext ≡ Encode(domain, B1, B2, SC1, SC2)
sid = HASH(protocolContext, aid, bid, nA)
```

### Source commitment

The concrete protocol defines:

```text
MA = (C, sid, m, A, B)
sigA = Sign(skA, H(MA))
t1 = (sid, m, A, B, sigA)
```

The Verifpal representation is:

```text
hMessageA = HASH(protocolContext, sid, m, aid, bid)
sigA = SIGN(skA, hMessageA)
t1 = CONCAT(sid, m, aid, bid, sigA)
```

Both `SC1` and `SC2` reconstruct the same authenticated value before verifying `sigA`.

The protocol digest is:

```text
d1 = HASH(t1)
```

### Delivery and acknowledgment

After `t1` has been accepted by `SC2`, the receiver obtains:

```text
D = (sid, m, d1)
```

The receiver generates a fresh nonce `nB` and constructs:

```text
Ack = (sid, d1, nB)
sigB = SIGN(skB, HASH(Ack))
t2 = (sid, d1, nB, sigB)
```

The corresponding digest is:

```text
d2 = HASH(t2)
```

The complete protocol later records on `B1`:

```text
t3 = (sid, H(t2), e2)
```

`t3` is a persistent source-chain completion record, not an additional cryptographic proof.

## Cross-chain evidence abstraction

The concrete protocol uses:

```text
VerifyEvidence_Bi(t, e)
```

with the soundness assumption:

```text
VerifyEvidence_Bi(t, e) = 1
    =>
    Included_Bi(t)
    AND Final_Bi(t)
    AND Bound_Bi(t, e)
    AND AcceptedBy_SCi(t)
```

where:

- `Included_Bi(t)` means the exact transaction or protocol-relevant event is included in a valid state of `Bi`.
- `Final_Bi(t)` means the event satisfies the required finality criterion.
- `Bound_Bi(t,e)` means the evidence is bound to that exact event and blockchain.
- `AcceptedBy_SCi(t)` means the event corresponds to a successfully committed execution of the designated protocol contract and transition.

A failed or reverted transaction must therefore not satisfy `VerifyEvidence`.

The internal implementation of `VerifyEvidence` is outside the Verifpal model.

## Verifpal representation of cross-chain verification

Concrete evidence objects `e1` and `e2` are not modeled directly.

Forward direction:

```text
v1 = HASH(t1)
SC1 -> SC2: t1, [v1]
```

abstracts:

```text
SC1 -> SC2: (t1, e1)
```

under:

```text
VerifyEvidence_B1(t1, e1) = 1
```

Return direction:

```text
v2 = HASH(t2)
SC2 -> SC1: t2, [v2]
```

abstracts:

```text
SC2 -> SC1: (t2, e2)
```

under:

```text
VerifyEvidence_B2(t2, e2) = 1
```

### Important distinction

```text
d1, d2   protocol digests
v1, v2   Verifpal-only verification handles
e1, e2   concrete cross-chain evidence
```

These are different classes of values.

## Guarded values

The following guarded values are modeling abstractions:

```text
[pkA]
[pkB]
[v1]
[v2]
[delivery]
```

- `[pkA]`, `[pkB]` — authentic participant/public-key bindings.
- `[v1]`, `[v2]` — successful external cross-chain evidence verification.
- `[delivery]` — receiver `B` obtains the commitment already accepted by `SC2` from authenticated `B2` state.

## Completion event

The Verifpal model defines:

```text
completion = HASH(sid, d1, d2)
```

This is only a symbolic query/precondition event.

```text
completion != t3
```

## Persistent state and replay resistance

Persistent smart-contract state is intentionally excluded from Verifpal.

The complete protocol maintains:

```text
state1[sid] ∈ {Idle, Committed, Completed}
state2[sid] ∈ {Idle, Accepted, Acknowledged}
```

with:

```text
SC1: Idle -> Committed -> Completed
SC2: Idle -> Accepted -> Acknowledged
```

Replay-resistant transition acceptance depends on:

```text
CryptographicallyValid(t)
AND ValidStateGuard(sid, t)
AND AtomicPersistentUpdate(sid)
    =>
AtMostOnce(sid, t)
```

This property is analyzed separately in the paper.

## Queries

The complete model contains 11 queries.

### Confidentiality

```text
confidentiality? skA
confidentiality? skB
```

### Authentication

```text
A   -> SC1 : t1
SC1 -> SC2 : v1
B   -> SC2 : t2
SC2 -> SC1 : v2
```

### Freshness

```text
sid
H(Ack)
```

### Equivalence

For executions reaching `completion`, the model checks correspondence of:

```text
sid
d1 = HASH(t1)
d2 = HASH(t2)
```

## Running the models

### Parse/check

```bash
chmod +x check_models.sh
./check_models.sh
```

To check one model:

```bash
verifpal pretty 01_symmetric_evidence_full.vp > /dev/null
```

### Run the complete model

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 1 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 3 --color never
```

### Run all experiments

```bash
chmod +x run_all.sh
./run_all.sh
```

The script stores:

```text
results/<model>_s<sessions>.log
results/<model>_s<sessions>.code
```

## Expected results

### Complete model

**1 session**

All 11 queries pass.

**2 sessions**

Two authentication queries fail:

```text
A -> SC1 : t1
B -> SC2 : t2
```

The remaining 9 queries pass.

**3 sessions**

The same two authentication queries fail; the remaining 9 queries pass.

The failures correspond to duplicate acceptance of already valid protocol objects in the intentionally stateless Verifpal abstraction.

### Authentication model

- 1 session: all authentication queries pass.
- 2 and 3 sessions: authentication of `t1` at `SC1` and `t2` at `SC2` fails.
- Authentication of `v1` and `v2` continues to pass.

### Session-freshness model

No query fails with 1, 2, or 3 sessions.

### Acknowledgment-binding model

No query fails with 1, 2, or 3 sessions.

### Negative freshness control

Positive model:

```text
sid = HASH(protocolContext, aid, bid, nA)
```

Negative control:

```text
sid = HASH(protocolContext, aid, bid)
```

Expected results:

| Query | 1 session | 2 sessions | 3 sessions |
|---|---|---|---|
| Freshness of `sid` | Fail | Fail | Fail |
| Freshness of `H(Ack)` | Pass | Pass | Pass |

Only `nA` is removed.

## Verification boundary

The Verifpal models analyze the cryptographic message layer under an active Dolev–Yao adversary.

They do not prove:

- blockchain consensus or finality;
- correctness of light clients or proof systems;
- implementation correctness of `VerifyEvidence`;
- persistent smart-contract state;
- atomic/serializable contract execution;
- unbounded-session security.

A passing Verifpal query means that no contradiction was found within the analyzed symbolic model, assumptions, search bounds, and selected number of sessions.
