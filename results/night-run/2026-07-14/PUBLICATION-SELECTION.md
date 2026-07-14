# Power Public-intake Selection

This Night Run branch retains every collected export, including superseded
runs and failures. Main receives only the latest successful, structurally
valid, protocol-conformant result for each App-selectable model and workload.

Selection was frozen on 2026-07-14. A result must contain all five completed
measured attempts. A later successful rerun supersedes an earlier run for
publication, but never deletes it from this branch.

| Model | Latest B-UX-001 | Latest B-PIPE-001 | App source |
| --- | --- | --- | --- |
| Llama 3.2 1B Instruct | 09:11:57Z | 09:12:52Z | 0.10.1 build 13 (`c8b1f7b`) |
| Gemma 3 1B IT | 08:35:00Z | 08:35:58Z | 0.10.0 build 12 (`07a7918`) |
| Granite 3.3 2B Instruct | 09:38:06Z | 09:40:45Z | 0.10.1 build 13 (`c8b1f7b`) |
| SmolLM3 3B | 09:20:02Z | 09:23:42Z | 0.10.1 build 13 (`c8b1f7b`) |
| LFM2 1.2B | 10:12:26Z | 10:13:20Z | 0.10.1 build 13 (`c8b1f7b`) |
| EXAONE 4.0 1.2B | 09:26:39Z | 09:27:55Z | 0.10.1 build 13 (`c8b1f7b`) |
| BitNet b1.58 2B 4T | 09:31:50Z | 09:33:59Z | 0.10.1 build 13 (`c8b1f7b`) |
| Llama 3.2 3B Instruct | 09:45:30Z | 09:48:52Z | 0.10.1 build 13 (`c8b1f7b`) |
| Qwen3 0.6B | 10:09:11Z | 10:09:47Z | 0.10.1 build 13 (`c8b1f7b`) |
| Qwen3 1.7B | 09:53:44Z | 09:55:34Z | 0.10.1 build 13 (`c8b1f7b`) |
| Qwen3 4B | 09:59:54Z | 10:04:40Z | 0.10.1 build 13 (`c8b1f7b`) |

The main-safe publication set therefore contains 22 result packages: one
B-UX-001 and one B-PIPE-001 package for each of the 11 models. Granite's
09:37:12Z failed B-UX-001 run and every earlier or superseded run remain only
as transparent Night Run evidence.
