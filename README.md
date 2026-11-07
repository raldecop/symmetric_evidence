# Symmetric Cross-Chain Evidence Protocol — Verifpal Models

This directory contains the Verifpal models and supporting scripts used for the cryptographic analysis of the **Symmetric Cross-Chain Evidence Protocol** described in the paper:

> *Symbolic Formalization and Verification of a Cryptographic Protocol for Symmetric Cross-Chain Evidence*

The symbolic models analyze the cryptographic message-exchange layer under an active Dolev–Yao adversary. They were evaluated with **one, two, and three concurrent sessions per principal** using **Verifpal 1.6.7**.

The persistent smart-contract state used by the complete protocol is intentionally not represented in Verifpal. Stateful replay resistance and at-most-once transition acceptance are analyzed separately through the state-transition model presented in the paper.

## Files

- `01_symmetric_evidence_full.vp` — complete cryptographic abstraction containing 11 queries:
  - 2 confidentiality queries,
  - 4 authentication queries,
  - 2 freshness queries, and
  - 3 equivalence queries.
- `02_authentication.vp` — targeted model containing the four authentication queries.
- `03_session_freshness.vp` — targeted model for session freshness and session correspondence.
- `04_ack_binding.vp` — targeted model for commitment–acknowledgment binding and return-path correspondence.
- `05_negative_no_fresh_nonce.vp` — negative-control model in which only the fresh sender nonce `nA` is removed from the session-identifier construction.
- `check_models.sh` — parses all `.vp` files using Verifpal and reports syntax/model-loading errors.
- `run_all.sh` — runs all five models with 1, 2, and 3 sessions and stores terminal output and compact result codes under `results/`.

## Verification boundary

The analysis is intentionally divided into three layers:

1. **Cryptographic message layer** — analyzed in Verifpal.
2. **Persistent-state layer** — analyzed separately through the protocol state-transition model.
3. **Blockchain-verification layer** — inherited from the underlying cross-chain interoperability mechanism.

The Verifpal models therefore do **not** constitute end-to-end verification of a concrete blockchain implementation.

### Cross-chain evidence assumption

The concrete protocol uses an abstract predicate

```text
VerifyEvidence_Bi(t, e)
```

whose successful evaluation is assumed to imply:

```text
Included_Bi(t)
AND Final_Bi(t)
AND Bound_Bi(t, e)
```

That is, the exact event `t` is included in an acceptable state of blockchain `Bi`, has reached the required finality level, and the evidence `e` is correctly bound to that event and blockchain.

Consensus correctness, light-client verification, finality mechanisms, Merkle-proof verification, succinct-proof verification, and other platform-specific mechanisms are outside the Verifpal model.

## Main modeling choices

The following abstractions are intentional.

1. `protocolContext` is a public atomic abstraction of the canonical ordered execution context

   ```text
   Encode(domain, B1, B2, SC1, SC2)
   ```

2. Protocol objects are represented at the field level to preserve the relevant cryptographic dependencies without modeling implementation-specific serialization.

3. `[pkA]` and `[pkB]` represent the assumed authentic binding between participant identities and their registered public keys. They do not represent additional public-key fields transmitted by the concrete protocol.

4. `d1` and `d2` are **protocol digests**:

   ```text
   d1 = HASH(t1)
   d2 = HASH(t2)
   ```

   They are not cross-chain evidence and are not Verifpal verification handles.

5. `[v1]` and `[v2]` are **Verifpal-only guarded verification handles** representing successful external verification of the corresponding cross-chain evidence:

   ```text
   VerifyEvidence_B1(t1, e1) = 1
   VerifyEvidence_B2(t2, e2) = 1
   ```

   They are not concrete evidence objects, finality proofs, or additional protocol fields.

6. `[delivery]` models receiver `B` obtaining the commitment already accepted by `SC2` from authenticated destination-chain state, rather than accepting an arbitrary network copy.

7. Persistent contract variables such as

   ```text
   state1[sid]
   state2[sid]
   ```

   are intentionally excluded from Verifpal and analyzed separately in the state-transition model.

8. `completion` is a **Verifpal-only query event** used to delimit executions that reach the final verification stage. It is not the concrete protocol completion record `t3`.

## Concrete protocol dependencies

The protocol defines the execution context as

```text
C = Encode(domain, B1, B2, SC1, SC2)
```

and constructs the session identifier as

```text
sid = H(C, A, B, NA)
```

where `NA` is a fresh sender nonce.

The sender-authenticated message is

```text
MA = (C, sid, m, A, B)
```

and the sender signature is

```text
sigA = Sign(skA, H(MA))
```

The source commitment is

```text
t1 = (sid, m, A, B, sigA)
```

with protocol digest

```text
d1 = H(t1)
```

After destination-side acceptance, receiver `B` obtains

```text
D = (sid, m, d1)
```

and constructs

```text
Ack = (sid, d1, NB)
sigB = Sign(skB, H(Ack))
t2 = (Ack, sigB)
```

where `NB` is a fresh receiver nonce.

The destination acknowledgment digest is

```text
d2 = H(t2)
```

and the persistent source-side completion record in the complete protocol is

```text
t3 = (sid, d2, e2)
```

or equivalently

```text
t3 = (sid, H(t2), e2)
```

The resulting protocol-level binding is

```text
t1 -> d1 -> Ack subset-of t2 -> d2 -> t3
```

## Verifpal field-level representation

The Verifpal model represents the same cryptographic dependencies as follows.

### Session identifier

```text
sid = HASH(protocolContext, aid, bid, nA)
```

### Sender authentication

```text
hMessageA = HASH(protocolContext, sid, m, aid, bid)
sigA = SIGN(skA, hMessageA)

t1 = CONCAT(sid, m, aid, bid, sigA)
```

Both `SC1` and `SC2` reconstruct the same authenticated value before verifying `sigA`.

### Source commitment digest and external-verification handle

```text
d1 = HASH(t1)
v1 = HASH(t1)
```

The model supplies `v1` to `SC2` as a guarded value:

```text
SC1 -> SC2: t1, [v1]
```

This symbolically abstracts the concrete protocol step

```text
SC1 -> SC2: (t1, e1)
```

under the assumption

```text
VerifyEvidence_B1(t1, e1) = 1
```

`SC2` independently reconstructs `HASH(t1)` and checks that it corresponds to the guarded verification handle.

### Delivery and acknowledgment

```text
delivery = CONCAT(sid, m, d1)

hAck = HASH(sid, d1, nB)
sigB = SIGN(skB, hAck)

t2 = CONCAT(sid, d1, nB, sigB)
```

### Destination acknowledgment digest and external-verification handle

```text
d2 = HASH(t2)
v2 = HASH(t2)
```

The model supplies `v2` to `SC1` as a guarded value:

```text
SC2 -> SC1: t2, [v2]
```

This symbolically abstracts

```text
SC2 -> SC1: (t2, e2)
```

under

```text
VerifyEvidence_B2(t2, e2) = 1
```

### Completion event

After verifying the returned acknowledgment and its bindings, the model constructs

```text
completion = HASH(sid, d1, d2)
```

This value is used only as a precondition for queries concerning completed symbolic executions.

It is important to distinguish:

```text
d1, d2      = protocol digests
v1, v2      = Verifpal-only verification handles
e1, e2      = concrete cross-chain evidence
completion  = Verifpal-only query event
t3          = persistent source-chain completion record
```

In particular,

```text
v1 != e1
v2 != e2
completion != t3
```

at the implementation/protocol level.

## Requirements

Confirm that Verifpal is available:

```bash
verifpal --version
```

The experiments reported in the paper were performed using:

```text
Verifpal 1.6.7
```

## 1. Parse/check the models

Run:

```bash
chmod +x check_models.sh
./check_models.sh
```

The script invokes:

```bash
verifpal pretty MODEL.vp
```

for each model. `pretty` requires successful parsing and model loading; its formatted output is discarded.

To check one model manually:

```bash
verifpal pretty 01_symmetric_evidence_full.vp > /dev/null
```

## 2. Run a single verification

Always specify the number of sessions explicitly.

```bash
verifpal verify 01_symmetric_evidence_full.vp --sessions 1 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 2 --color never
verifpal verify 01_symmetric_evidence_full.vp --sessions 3 --color never
```

The same pattern applies to the remaining models.

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

# Expected results

## 01 — Full model

### 1 session

All **11 queries pass**:

- 2 confidentiality,
- 4 authentication,
- 2 freshness,
- 3 equivalence.

### 2 sessions

Exactly two authentication queries fail:

```text
authentication? Sender -> Sc1: t1[precondition[Sc1 -> Sender: completion]]
authentication? Receiver -> Sc2: t2[precondition[Sc1 -> Sender: completion]]
```

Verifpal classifies both failures as:

```text
duplicate acceptance: no recipient-generated context
```

The remaining **9 queries pass**, including:

```text
authentication? Sc1 -> Sc2: v1
authentication? Sc2 -> Sc1: v2
```

as well as both freshness and all three equivalence queries.

### 3 sessions

The result is identical to the two-session analysis:

- authentication of `t1` at `SC1` fails;
- authentication of `t2` at `SC2` fails;
- the remaining 9 queries pass.

## 02 — Authentication model

With **1 session**, all four authentication queries pass.

With **2 and 3 sessions**, the same two queries fail:

- authentication of `t1` at `SC1`;
- authentication of `t2` at `SC2`.

The authentication queries associated with the guarded cross-chain verification handles continue to pass:

```text
Sc1 -> Sc2: v1
Sc2 -> Sc1: v2
```

The two failures are classified as:

```text
duplicate acceptance: no recipient-generated context
```

These failures correspond to replay of already valid signed protocol objects, not signature forgery or substitution of the externally verified objects.

## 03 — Session-freshness model

No query fails with **1, 2, or 3 sessions**.

The positive model uses:

```text
sid = HASH(protocolContext, aid, bid, nA)
```

The results show that the modeled session freshness and session correspondence remain satisfied for the tested session bounds.

## 04 — Acknowledgment-binding model

No query fails with **1, 2, or 3 sessions**.

The model checks the correspondence of the locally reconstructed protocol values, including:

```text
sid
d1 = HASH(t1)
d2 = HASH(t2)
```

The results show that the modeled commitment–acknowledgment and return-path bindings remain satisfied for all tested session counts.

## 05 — Negative freshness control

The negative-control model changes only the session-identifier construction.

Positive model:

```text
sid = HASH(protocolContext, aid, bid, nA)
```

Negative control:

```text
sid = HASH(protocolContext, aid, bid)
```

All remaining elements of the cryptographic abstraction are unchanged.

The query

```text
freshness? sid[precondition[Sc1 -> Sender: completion]]
```

fails with **1, 2, and 3 sessions**.

The freshness query associated with the acknowledgment digest continues to pass because `nB` remains freshly generated.

Thus, the negative-control experiment isolates the contribution of the sender nonce `nA` to session freshness.

# Interpretation

The concurrent-session failures in Models 01 and 02 do **not** demonstrate:

- signature forgery,
- private-key compromise,
- substitution of the externally verified protocol objects,
- failure of session freshness, or
- failure of commitment–acknowledgment binding.

Instead, they correspond to replay of an already cryptographically valid `t1` or `t2`.

Because the Verifpal abstraction intentionally omits persistent smart-contract state, it has no state variable recording that an object associated with a particular `sid` has already produced its corresponding protocol transition. Consequently, the same valid object can be accepted again in the stateless symbolic abstraction.

The experiments therefore establish the distinction:

```text
Fresh(sid) AND CryptographicallyValid(t)
    does not imply
AtMostOnce(sid, t)
```

or, formally,

```text
Fresh(sid) ∧ CryptographicallyValid(t)
    ⇏ AtMostOnce(sid, t)
```

Replay-resistant transition acceptance belongs to the **stateful layer** of the complete protocol. As analyzed separately in the paper, it depends on the combination of:

```text
Cryptographic validity
AND valid state guard
AND atomic persistent state update
```

rather than on persistent storage alone.

The complete protocol therefore relies on persistent per-session contract state, state-dependent guards, and atomic guard-and-update execution to prevent a replayed cryptographically valid object from producing the same state transition more than once.

# What Verifpal does and does not establish

The Verifpal experiments provide machine-assisted symbolic analysis of the cryptographic message layer under the stated model and assumptions.

They analyze:

- signing-key confidentiality;
- authenticated origin of the signed commitment and acknowledgment;
- symbolic correspondence of the cross-chain verification handles;
- session freshness;
- acknowledgment freshness;
- session correspondence;
- commitment–acknowledgment binding.

They do **not** directly establish:

- consensus correctness;
- blockchain finality;
- light-client correctness;
- correctness of Merkle or succinct proof verification;
- soundness of a concrete `VerifyEvidence` implementation;
- persistent smart-contract state semantics;
- atomic or serializable contract execution;
- unbounded-session security.

These properties are either explicit external assumptions or are analyzed separately through the state-transition model.

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

A passing query means that Verifpal found no contradiction within the analyzed symbolic model, assumptions, search limits, and selected session count.

The experiments with one, two, and three sessions are therefore **bounded symbolic analyses**. They do not constitute an unbounded proof for an arbitrary number of concurrent executions.

The complementary state-transition argument is stated for an arbitrary session identifier `sid`, but it is a deductive state analysis rather than a machine-checked Verifpal state-space exploration.