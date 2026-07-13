# Power Candidate Model Audit — 2026-07-13

## Decision

The public Models view is an actionable testing queue, not a directory of every
public-weight language model.

- Eight exact 4-bit artifacts are selectable in Reference App `0.10.0` build
  `12`.
- Four small artifacts remain visible as compatibility reviews with a specific
  recorded blocker.
- Eleven previously requested large models are retained in the machine-readable
  catalog as `reviewedIneligible`, but are not rendered on the website or added
  to the App.

No audit entry is a benchmark result, compatibility proof, deployment claim, or
performance estimate. Physical-device evidence remains `untested` until an
unmodified App export passes the Power contribution process.

## Audit boundary

The audit uses the dependencies locked by the App:

- MLX Swift LM `3.31.4`, revision
  `bd4b7434e6bdb588c7ef55706ff8904cb7fd4c57`;
- MLX Swift `0.31.6`; and
- the model-type registry in the pinned
  [LLMModelFactory.swift](https://github.com/ml-explore/mlx-swift-lm/blob/bd4b7434e6bdb588c7ef55706ff8904cb7fd4c57/Libraries/MLXLLM/LLMModelFactory.swift).

The registry answers only whether that MLX Swift LM revision contains a loader
for a `model_type`. It is not an Apple-device certification list. A usable
Power candidate additionally needs:

1. a specific MLX Safetensors artifact;
2. a 40-character pinned artifact revision;
3. a tokenizer and configuration accepted by the current App path;
4. request-template behavior compatible with the frozen workload;
5. a practical initial device-scale target, currently at most the 3B total
   parameter class with a 4-bit artifact; and
6. license and source metadata that can be reviewed independently.

This is why “supported by MLX” and “can be selected for a Power benchmark” are
not equivalent.

## App-ready candidates

All eight rows have a registered model type and a pinned 4-bit artifact. They
remain explicitly untested on a physical iPhone.

| Priority | Artifact | Type | Snapshot bytes | Audit role |
| ---: | --- | --- | ---: | --- |
| 1 | `mlx-community/Llama-3.2-1B-Instruct-4bit@08231374eeacb049a0eade7922910865b8fce912` | `llama` | 712,593,855 | widely used 1B family baseline |
| 2 | `mlx-community/gemma-3-1b-it-qat-4bit@15fed4eafb456c6fcb2a1165f19ac609670ed14b` | `gemma3_text` | 771,863,021 | same-size cross-family QAT candidate |
| 3 | `mlx-community/granite-3.3-2b-instruct-4bit@58246c5498495c14599525c852cfadb66c9f3084` | `granite` | 1,430,233,125 | Apache-2.0 2B tier candidate |
| 4 | `mlx-community/SmolLM3-3B-4bit@d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce` | `smollm3` | 1,747,380,812 | 3B upper-bound candidate |
| 5 | `mlx-community/LFM2-1.2B-4bit@3843e4ad0fcb8b7ed8a050908ac8f0bb5320d1bf` | `lfm2` | 663,392,070 | compact hybrid architecture |
| 6 | `mlx-community/exaone-4.0-1.2b-4bit@6dbf5f06dcb9526a7c328f692b1e08d35e17bff2` | `exaone4` | 731,129,626 | compact multilingual family |
| 7 | `mlx-community/bitnet-b1.58-2B-4T-4bit@f4c3737ce9cd34ffe48a01647e779a68f97f08b1` | `bitnet` | 723,946,800 | alternative weight architecture |
| 8 | `mlx-community/Llama-3.2-3B-Instruct-4bit@7f0dc925e0d0afb0322d96f9255cfddf2ba5636e` | `llama` | 1,824,825,759 | 1B-to-3B same-family scaling control |

The exact source, base-model license, and artifact metadata for every row are
recorded in [power-test-catalog.json](power-test-catalog.json).

## Small-model compatibility reviews

These models are relevant in scale but are not App-selectable.

| Artifact | Why it is not ready |
| --- | --- |
| `mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit@933185be1b8f81d9a21dcfa15ff73470d3545240` | The artifact template opens a reasoning block and does not honor the frozen non-thinking behavior used by B-UX-001. The registered `qwen2` loader alone is insufficient. |
| `mlx-community/Qwen3.5-2B-4bit@674aaa7240b91e8012fcad5d791b7dfe5ba90207` | The published artifact uses an image-text-to-text/multimodal path. The current App uses MLXLLM's text path, so loading and token accounting must be verified before enabling it. |
| `mlx-community/AI21-Jamba-Reasoning-3B-4bit@9517347b9396e80a21750de4d7354c45da98776f` | The artifact template forces reasoning rather than the frozen non-thinking request behavior. |
| `mlx-community/OpenELM-270M-Instruct@7cb5ebd2e82067793db75003630ed2442a16a29d` | The artifact is not 4-bit and lacks the chat template required by the current request construction. |

Resolving a blocker may make an artifact eligible for a later App version. It
must not silently change Power 1.0 workload semantics.

## Reviewed but not recommended for iPhone testing

The previously requested GLM 5.x, Kimi K2.x, DeepSeek V4, MiMo V2.5 Pro,
MiniMax M2.7/M3, Gemma 4 31B, and Nemotron 3 Ultra entries exceed the initial
3B total-parameter boundary and do not have an approved practical 4-bit App
artifact. Their public weights or license labels therefore do not make them
actionable Power candidates.

They remain in `reviewedIneligible` for traceability, including the official
model and license links, but the website intentionally does not display them.
A smaller derivative must be audited under its own artifact identity; it cannot
be reported as the original large model.

## Is every small MLX model included?

No. The MLX Swift repository contains more registered types and example presets
than the candidate catalog. Registration is necessary but not sufficient, and
the candidate list is curated rather than exhaustive.

Examples reviewed but not promoted include older or redundant family baselines
such as SmolLM 135M, Qwen2.5 1.5B, and Gemma 2 2B; BF16 or template-incomplete
artifacts such as ERNIE 0.3B, Lille 130M, and OpenELM; and models whose execution
semantics do not match the current autoregressive TTFT/decode contract, such as
the 3B Nemotron diffusion model. MoE artifacts are evaluated by total device
footprint rather than active-parameter marketing labels.

The catalog should be re-audited when the App updates its locked MLX Swift LM
revision. New registry support never enters the App automatically.

## Reproduction of this audit

For every App-ready or compatibility-review row, verify all of the following:

1. the artifact URL contains the cataloged revision;
2. `config.json` declares the cataloged `model_type`;
3. that type is handled by the pinned `LLMModelFactory.swift` or the recorded
   alternate loader path;
4. tokenizer/config/template files exist and their behavior matches the frozen
   benchmark request;
5. the snapshot byte total matches the catalog; and
6. the base-model license link is inspectable.

The audit deliberately stops before claiming physical-device success. That
claim begins only when a genuine result is exported and reviewed.
