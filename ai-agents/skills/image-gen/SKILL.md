---
name: image-gen
description: Generate images locally on hopper's R9700 GPU using stable-diffusion.cpp + Chroma, rendering at 512x512 and Lanczos-upscaling to 1024x1024 (~15s per image). Use when asked to create, draw, render or generate an image, picture, illustration, icon, wallpaper or diagram-as-art locally. Triggers on "generate an image", "make me a picture", "stable diffusion", "chroma", "image-gen", or working in /srv/selfhost/image-gen.
tools: Read, Bash, Write, Edit
---

# image-gen

Text-to-image on **hopper**, entirely local. `stable-diffusion.cpp` (Vulkan)
serves **Chroma 8.9B Q8_0** from a container; the wrapper script handles GPU
arbitration, pre-warming, and upscaling.

Deployment lives in `/srv/selfhost/image-gen` (Dockerfile, compose, README).
Background and the full measurement history: `[[local-image-generation]]`
(`/srv/selfhost/wiki/llm/todos/local-image-generation.md`).

## The one thing to know first

**The GPU holds Chroma or an LLM, never both.** Chroma needs 14.40 GiB of the
card's 31.86 GiB; a loaded `llama-server` holds 14–23 GiB. Overlap kills the
Vulkan queue mid-sample with `vk::DeviceLostError`. So generating an image
**evicts whatever model hermes was using**, and you must give the card back when
you're done. The script does both, but *you* have to remember the `down`.

## Usage

```bash
S=~/.claude/skills/image-gen/scripts/imagegen.py

python3 $S gen "a red fox reading a book by candlelight" -o ~/pics/fox.png
python3 $S down     # ALWAYS, when finished — releases the card to llama-swap
```

`gen` auto-starts the server if it isn't up (evict LLM → compose up → pre-warm,
~75s once), then renders. Print the resulting path to the user; use
`SendUserFile` if they'll want to look at it.

| flag | default | notes |
|---|---|---|
| `-o PATH` | required | output PNG |
| `--size N` | 512 | render resolution, square |
| `--upscale N` | 1024 | Lanczos target; `<= --size` disables |
| `--native` | off | no upscale, keep `--size` output |
| `--steps N` | 26 (server) | below ~20 Chroma degrades visibly |
| `--seed N` | server default | byte-reproducible; verified |
| `--negative` | — | negative prompt |
| `--keep-source` | off | keep the pre-upscale 512 PNG |

Other subcommands: `up` (`--no-prewarm`), `down`, `status`. Global `-v` reports
lifecycle steps; without it each run prints one outcome line to stderr and the
output path to stdout, so `$(python3 $S gen ... -o x.png)` is the path.

For anything the script doesn't cover — img2img, LoRA, ControlNet, hires-fix —
call the HTTP API directly (see *API shape* below) rather than growing the script
speculatively.

## Why 512-then-upscale is the default

Attention is quadratic in latent tokens, so 1024² costs ~4.7× a 512² render
while this model is at its best near 512. Measured 2026-08-03, warm, seed 42:

| path | time |
|---|---|
| **512² + Lanczos → 1024²** | **13.9s + 0.37s = ~14.3s** |
| native 1024² | 70.9s |

That is the accepted trade: you get 512² of real detail, resampled. On the fox
prompt the upscaled 512 actually looked *richer* than the native 1024 — Chroma
flattens above its sweet spot. Offer `--size 1024 --native` when the user
explicitly wants maximum fidelity and will wait ~71s.

## Timing, so you can set expectations

| | cost |
|---|---|
| cold start (`up`, incl. pre-warm) | ~75s |
| warm 512² render | 13.9s |
| Lanczos 512→1024 | 0.37s |
| warm 512² at `--steps 8` | 7.3s |
| warm native 1024² | 70.9s |

Weights load **lazily, per component, on the first request** — not at startup.
The startup line `total params memory size = 18528.14MB` is a size stat, not an
allocation; the real reads (T5 16.0s, diffusion 18.3s, VAE 0.5s) land inside
request 1, making it ~49s instead of 14s. That is exactly what `up`'s pre-warm
(a throwaway 256², 4 steps) absorbs. Don't skip it before a user-visible render.

## Prompting Chroma

Chroma is Flux-schnell-class, de-distilled, T5-conditioned and uncensored. It
reads natural language, not booru tags. Prefer a descriptive sentence with
subject, style, lighting and composition — "a red fox reading a book by
candlelight, detailed illustration, warm rim light" over "fox, book, candle,
masterpiece, 8k".

Do **not** try to buy speed with `--cfg-scale 1.0` or `--steps 10`: measured
faster (53s vs 72s at the time) but visibly washed out and flat. Being
de-distilled, Chroma needs real CFG and a full step count. The knobs already set
in the compose file (`--diffusion-fa`, `easycache` threshold 0.25) are the ones
that were free.

## API shape

`POST /v1/images/generations` on `127.0.0.1:1234`, OpenAI-shaped, returns
`{data:[{b64_json}]}`. There is **no** `/generate` route (404) and
`/sdcpp/v1/capabilities` **500s** on this build — probe readiness with
`GET /v1/models`.

The OpenAI route only accepts `prompt`, `n`, `size`, `output_format`,
`output_compression`. Everything else rides inside the prompt as native-schema
JSON, which the server strips before generating:

```
a red fox <sd_cpp_extra_args>{"seed":42,"sample_params":{"sample_steps":26}}</sd_cpp_extra_args>
```

Also served: `POST /sdapi/v1/txt2img` (A1111 — has `enable_hr` / `hr_upscaler`
for in-process hires-fix) and `POST /sdcpp/v1/img_gen` (native, async, pairs with
`GET /sdcpp/v1/jobs/{id}`). Full reference: upstream `examples/server/api.md`.

## Failure modes

| symptom | cause |
|---|---|
| `vk::DeviceLostError`, `context is lost` | an LLM still held VRAM; `down`, unload, retry |
| `refusing to start: N GiB still in use` | the script's gate worked — find the holder with `rocm-smi --showpids` |
| `get sd version from file failed` | someone passed `-m`; the Chroma GGUF is a standalone UNet and needs `--diffusion-model` |
| `failed to allocate Vulkan0 buffer of size 8545370120` | `--vae-tiling` missing; untiled 1024² decode wants one 7.96 GiB buffer |
| `unknown argument: --flag=value` | sd.cpp's parser is space-separated only |
| hermes/LLM answers stop working | image-gen is still up holding the card. `down`. |

The container is `restart: "no"` deliberately — `unless-stopped` would hold
14.40 GiB across every reboot and silently break the LLM stack. Don't "fix" it.

## Conventions

- Write outputs where the user asked, else `/srv/selfhost/image-gen/out/`. Never
  scatter PNGs in the cwd.
- Don't leave the server up "in case". One `down` costs nothing; a held card
  breaks every other model on the box.
- Report the real numbers, not the table's. Each `gen` prints its own timings.
