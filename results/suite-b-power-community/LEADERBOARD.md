# Power Community Live Ranking

This live view combines the immutable Power 1.1 Maintainer Reference results with valid merged community submissions.
A GitHub account counts once per exact comparison cell and may contribute independently to any number of different cells.
The default table shows the newest App baseline inside each model, device, runtime, and iOS minor family. Exact patch builds and older App baselines remain in normalized evidence and coverage history.

## Responsiveness

Current display: 11 model configurations; 3 ranked; 8 retained without a rank.

| Rank | Model | Quant | Proxy TTFT | App | iOS | Device | Contributors | Runs | Status | Variation |
| ---: | --- | --- | ---: | --- | --- | --- | ---: | ---: | --- | ---: |
| 1 | Qwen3 0.6B | 4-bit | 183.09 ms | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 2 | Qwen3 1.7B | 4-bit | 487.73 ms | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 3 | Qwen3 4B | 3-bit | 1137.58 ms | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |

### Current configurations without a rank

These exact cells are retained, but no metric-eligible Proxy TTFT is available.

| Model | Quant | App | iOS | Device | Reason |
| --- | --- | --- | --- | --- | --- |
| BitNet b1.58 2B 4T | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| EXAONE 4.0 1.2B | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| Gemma 3 1B IT | 4-bit | 0.10.0 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| Granite 3.3 2B Instruct | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| LFM2 1.2B | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| Llama 3.2 1B Instruct | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| Llama 3.2 3B Instruct | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |
| SmolLM3 3B | 4-bit | 0.10.1 | 26.5.2 | iPhone15,3 | No metric-eligible Proxy TTFT |

## Sustained generation

Current display: 11 model configurations; 11 ranked; 0 retained without a rank.

| Rank | Model | Quant | Decode | App | iOS | Device | Contributors | Runs | Status | Variation |
| ---: | --- | --- | ---: | --- | --- | --- | ---: | ---: | --- | ---: |
| 1 | Qwen3 0.6B | 4-bit | 96.84 tok/s | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 2 | Gemma 3 1B IT | 4-bit | 65.21 tok/s | 0.10.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 3 | LFM2 1.2B | 4-bit | 64.59 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 4 | Llama 3.2 1B Instruct | 4-bit | 60.25 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 5 | EXAONE 4.0 1.2B | 4-bit | 49.36 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 6 | Qwen3 1.7B | 4-bit | 40.97 tok/s | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 7 | BitNet b1.58 2B 4T | 4-bit | 33.56 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 8 | Granite 3.3 2B Instruct | 4-bit | 18.15 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 9 | Llama 3.2 3B Instruct | 4-bit | 14.59 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 10 | SmolLM3 3B | 4-bit | 13.95 tok/s | 0.10.1 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |
| 11 | Qwen3 4B | 3-bit | 9.82 tok/s | 0.13.0 | 26.5.2 | iPhone15,3 | 1 | 1 | Single contributor | — |

Power 1.0 and every historical community result remain immutable. This file is a reproducible live derivative of Power 1.1 plus retained merged community evidence.
