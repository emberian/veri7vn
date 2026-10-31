# Frozen activation binding pilot

This is an executable, untrusted research pipeline, not a shipped specialist.
**The root-authorized two-group macOS smoke is recorded below; no specialist
panels have run. There are no panel numbers or general usefulness claims.**
Rust execution remains with the central runner.

The readout maps a supplied value span's frozen contextual activation to one of
nine request-local entity × role cells. It actually fits and evaluates a small
linear multiclass ridge head; it does not ask a language model to invent labels.
It retains competing scores, original source spans and unknown coverage. It
requires exactly three candidate entities and roles in this first bounded pilot.
Candidate value boundaries are supplied, so its scores measure binding given
candidate spans, **not end-to-end discovery of arbitrary document facts**.

## Runner commands

From the repository root, using an environment with numpy:

```
python tools/research/binding_readout/pipeline.py generate --groups 60 --output var/binding-pilot.jsonl
python tools/research/binding_readout/pipeline.py run --data var/binding-pilot.jsonl --output var/binding-controls.json
python -m unittest discover -s tests/research -p test_binding_readout.py
```

For activations, an existing environment also needs torch and transformers with a
fast tokenizer. Supply the **local snapshot directory**, never a remote model ID:

```
python tools/research/binding_readout/pipeline.py run --data var/binding-pilot.jsonl --model /absolute/local/snapshot --layer 3 --output var/binding-activation.json
```

`local_files_only=True` is enforced for model and tokenizer. There are no downloads,
credentials, API calls, base-model training, generation or device auto-selection.
The head runs on CPU; frozen forwards also default to CPU. No full token histories
are persisted. Max 1,200 documents and 512 tokens each; oversize documents fail
instead of being silently truncated. Start with two groups per split before the
60-group run. At 600 passages the token-forward ceiling is 307,200; actual token
count will be smaller. One selected hidden layer is mean-pooled over each value
span. Forward APIs may transiently allocate all hidden layers; the tiny model
keeps this pilot bounded. No quantized GGUF hooks are assumed.

Read-only inventory found a local complete-looking
`~/.cache/huggingface/hub/models--EleutherAI--pythia-70m/snapshots/*` with
config, tokenizer and model.safetensors on an M2 Max with 96 GB RAM. File presence
is not a successful load. The project .venv lists numpy/sklearn, but no torch or
transformers. Root should select an already provisioned environment or explicitly
allocate dependencies; this lane installed nothing. Pythia-70m is a resource
smoke pilot, not a claim that a 70M model matches the paper's large models.

## Data and controls

Each JSONL document has id, group, split, origin, text, three `entities`, three
`roles`, candidate `values`, and gold `[entity_index, role_index]` labels in value
order. Spans have `start`, `end`, `text`, using Unicode codepoint offsets in the
original document. Labels are never passed to activation collection or controls.
The roster order defines local indices; it does not create persistent identities.

Synthetic binding tables randomize entity order, role order, assignments, and
sentence order. Both paraphrases of a table remain in the same split/group.
Reports separate held-out multiword names, unseen role labels and an unseen
sentence template; they do not select layers or penalties on held-out results.
The threshold is predeclared at .5, penalty at 10 and layer at 3. Change these only
using a new development run and disclose that selection. Position features and
whole-document hashed bag-of-token features are fit with the same head, and each
feature family also has a shuffled-training-label head. Training scores are
reported visibly alongside development and each test split, not presented as
held-out evidence. Probabilities are softmax-transformed ridge scores, **not
calibrated semantic confidence**; Brier score and risk/coverage at the fixed
threshold expose that limitation. Complete-table and tuple scores are distinct.
Wilson intervals are descriptive and explicitly flag shared-passage dependence.

Independent prose is a required missing control: append genuinely human-authored,
independently annotated documents with `origin: human`, `split: test_human`, and
whole-document `group` IDs, never used for fitting. Keep source provenance and
license beside the dataset. The fixture in tests is agent-authored prose and is
not counted as human evidence. Do not relabel synthetic paraphrases as human.
Report each prose source separately and compare role reversal, quoted attribution,
negation, reassignment, multiword names, and misleading ordering. This pilot forces
one cell per candidate; absent, ambiguous, contradictory and unsupported values
need explicit rejection supervision before general document extraction. Its
softmax abstention alone does not solve these cases. No usefulness claim should
be accepted without this independent control, an annotated rejection set, and a
predeclared selective-error target; a negative result is useful.

## Consumer boundary

`bridge` emits `oracle.binding-candidates.v1`: source digest, local entity/role/value
spans, score, untrusted status, and unknown coverage. It deliberately cannot set
world-completeness, uniqueness, source entailment or canonical graph IDs.
The native `binding_proposal::resolve` consumer now resolves full local labels
against the lexicon in the explicit admitted image. It keeps original Unicode
source spans separate from normalized lookup byte coordinates, retains lexical
ambiguity and emits validated typed programs. Attribute roles produce
Find → QueryAttr; relation roles produce Find → Relate(forward) → What. Forward
direction is an explicit conditional query assumption; reading a span does not
establish the asserted relation or a unique canonical entity. Unresolved labels
remain visible. No learned score becomes corpus support, an entity ID, or coverage.

The executable native example accepts IMAGE EXPECTED_SHA256 SOURCE_UTF8
PROPOSAL_JSON, then uses existing batch::prepare_program and batch::execute on all
resolved alternatives. Its output attaches unknown candidate coverage to the
conditional image denotations, even when all answers agree:

```
python tools/research/binding_readout/pipeline.py export --data var/binding-readout/smoke.jsonl --report var/binding-readout/smoke-report.json --id test_names-0-0 --source-output var/binding-readout/source.txt --proposal-output var/binding-readout/proposal.json
cargo run -p oracle-runtime-core --example binding_proposal -- IMAGE EXPECTED_SHA256 var/binding-readout/source.txt var/binding-readout/proposal.json
```

Synthetic invented names will normally remain unresolved in a real image. The
independent Rust fixture supplies Alice/score/10 in an explicit tiny image and
checks the real conditional quantity result; another fixture preserves both
attribute and relation readings of the same label. Native example/tests await
central execution. Source data never enters graph storage. The current grammar
`LearnedCandidate` remains a different type with different obligations.


The hypothesis comes from Dai, Heinzerling & Inui's ACL 2026 CBR paper,
https://aclanthology.org/2026.acl-long.2194/ (local binding.txt §3.1–3.3): linear/PLS
decoding of discourse entity/relation indices at attribute positions. This pilot
uses a multiclass ridge head rather than reproducing PLS or causal patching.
It tests usefulness; no mechanistic explanation or symbolic derivation is required.
No theorem statements are added and no proofs of neural reading are claimed.

## Authorized macOS smoke: actual result

The two-group run completed locally using the existing chetgpt environment:
Python fixtures **6 passed**; controls took **0.24 s**, frozen activations and all
heads **15.29 s**, activation process maximum RSS **700,973,056 bytes**. It used
Pythia-70m snapshot `a39f36b100fe8a5377810d56c3f4789b9c53ac42`, layer 3,
CPU threads 2, numpy 2.2.6, torch 2.12.0, transformers 4.57.3. No downloads or
installation occurred. Full results and model/config/tokenizer/environment
metadata hashes are in `native/evidence/2026-10-31-binding-pilot.json`.

Correct value-to-cell assignments out of 36 per split:

| Split | Activations | Shuffled activation labels | Position | Bag of tokens |
|---|---:|---:|---:|---:|
| Train | 36 | 6 | 9 | 4 |
| Development | 8 | 5 | 5 | 4 |
| Held-out names | 5 | 9 | 3 | 4 |
| Held-out roles | 11 | 4 | 3 | 4 |
| Held-out template | 6 | 4 | 4 | 4 |

Every held-out complete table failed. At the predeclared .5 acceptance threshold,
**all heads abstained on every value, including training values**. Exporting the
name-heldout source/proposal pair succeeded and correctly retained zero accepted
bindings. Independent bridge fixtures exercise nonempty known-correct and wrong
bindings. The native example and ten native fixtures still await central build
execution; no Rust run is implied by the Python bridge checks.

This is a negative tiny pilot with severe overfitting and no useful answered
coverage. The held-out name readout loses to shuffled labels; training 36/36 is
not evidence of transfer. Do not lower the threshold after seeing these results
and call that success. Human prose is still absent. Next decisions require a
separately declared experiment and actual independent annotations, not more
training-accuracy reporting. The supplied value candidates also remain a strong
oracle; this pilot has not demonstrated automatic mention discovery.

The native proposal report now keeps every retained field private and exposes
immutable slices; callers cannot detach vectors from their memory guard. Typed
input capacities are charged during resolution, and unresolved output copies
compact strings rather than retaining spare caller capacity. Original Unicode
span validation uses one metered coordinate index, charged byte comparisons and
checked lookup for oversized indices. The full report also obeys the admitted
image's result-byte cap. These changes and their ownership/Unicode/capacity
regressions await central Rust validation; the Python pilot results above are
unchanged.
