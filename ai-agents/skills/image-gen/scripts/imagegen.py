#!/usr/bin/env python3
"""Render images on hopper's R9700 via the containerised stable-diffusion.cpp server.

Default path is render-small-then-upscale: Chroma at 512x512 (~15s) followed by a
Lanczos resize (~0.4s), which is ~4.5x faster than a native 1024x1024 render and
visually comparable on this model. Pass --native to skip the trick.

The card cannot hold Chroma and an LLM at once, so `up` evicts llama-swap first
and `down` gives the card back. Always `down` when finished.
"""

import argparse
import base64
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

COMPOSE_DIR = Path("/srv/selfhost/image-gen")
SD_URL = "http://127.0.0.1:1234"
LLAMA_SWAP_URL = "http://127.0.0.1:8090"
CONTAINER = "image-gen"
CARD = "card0"  # the R9700; card1 is the iGPU
VRAM_FREE_THRESHOLD = 2 * 1024**3  # Chroma needs 14.40 GiB of the card's 31.86


VERBOSE = False


def log(msg):
    """Lifecycle progress — suppressed unless -v. Outcomes use say()."""
    if VERBOSE:
        print(f"imagegen: {msg}", file=sys.stderr, flush=True)


def say(msg):
    print(f"imagegen: {msg}", file=sys.stderr, flush=True)


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kw)


def vram_used():
    """Bytes in use on the R9700, via rocm-smi."""
    out = run("rocm-smi", "--showmeminfo", "vram", "--csv").stdout
    for line in out.splitlines():
        parts = line.split(",")
        if parts[0] == CARD:
            return int(parts[2])
    raise RuntimeError(f"{CARD} not found in rocm-smi output")


def server_ready():
    """No /health route exists, and /sdcpp/v1/capabilities 500s on this build."""
    try:
        with urllib.request.urlopen(f"{SD_URL}/v1/models", timeout=2) as r:
            return r.status == 200
    except (urllib.error.URLError, OSError):
        return False


def container_running():
    out = run("docker", "ps", "--filter", f"name=^{CONTAINER}$", "--format", "{{.Names}}").stdout
    return CONTAINER in out.split()


def unload_llm():
    """Evict whatever llama-swap has resident. GET, not POST — POST is a 404."""
    try:
        with urllib.request.urlopen(f"{LLAMA_SWAP_URL}/unload", timeout=30) as r:
            log(f"llama-swap unload -> {r.status}")
    except urllib.error.URLError as e:
        log(f"llama-swap unreachable ({e}) — assuming nothing to unload")


def up(prewarm=True):
    if server_ready():
        log("server already up")
        return

    unload_llm()
    for _ in range(20):
        used = vram_used()
        if used < VRAM_FREE_THRESHOLD:
            break
        log(f"waiting for VRAM to free ({used / 1024**3:.2f} GiB in use)")
        time.sleep(1.5)
    else:
        raise SystemExit(
            f"refusing to start: {used / 1024**3:.2f} GiB still in use on {CARD}. "
            "Chroma needs 14.40 GiB and a collision kills the Vulkan queue with "
            "vk::DeviceLostError. Find the holder with `rocm-smi --showpids`."
        )

    log("starting sd-server")
    run("docker", "compose", "up", "-d", cwd=COMPOSE_DIR)
    for _ in range(40):
        if server_ready():
            break
        time.sleep(1)
    else:
        raise SystemExit("sd-server did not become healthy; check `docker compose logs`")

    if prewarm:
        # Weights load lazily on the first request, not at startup: ~36s of
        # disk -> VRAM that would otherwise be charged to the user's first image.
        log("pre-warming (loads weights, ~40s)")
        t = time.time()
        generate("a grey square", size=256, steps=4)
        log(f"warm after {time.time() - t:.1f}s")


def down():
    if not container_running():
        say("already stopped")
        return
    run("docker", "compose", "down", cwd=COMPOSE_DIR)
    say(f"stopped; {vram_used() / 1024**3:.2f} GiB in use on {CARD}")


def generate(prompt, size=512, steps=None, seed=None, negative=None):
    """Returns raw PNG bytes."""
    # The OpenAI route only understands prompt/n/size/output_format. Everything
    # else (seed, steps, negative prompt) rides along as native-schema JSON in a
    # <sd_cpp_extra_args> tag inside the prompt, which the server strips out.
    extra = {}
    if seed is not None:
        extra["seed"] = seed
    if negative:
        extra["negative_prompt"] = negative
    if steps is not None:
        extra["sample_params"] = {"sample_steps": steps}
    if extra:
        prompt = f"{prompt} <sd_cpp_extra_args>{json.dumps(extra)}</sd_cpp_extra_args>"

    payload = {"prompt": prompt, "size": f"{size}x{size}", "n": 1}

    req = urllib.request.Request(
        f"{SD_URL}/v1/images/generations",
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as r:
        body = json.load(r)
    return base64.b64decode(body["data"][0]["b64_json"])


def upscale(src, dst, target):
    run("magick", str(src), "-filter", "Lanczos", "-resize", f"{target}x{target}", str(dst))


def cmd_gen(args):
    if not server_ready():
        up()

    out = Path(args.out).expanduser().resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    render = args.size
    t = time.time()
    png = generate(args.prompt, size=render, steps=args.steps, seed=args.seed,
                   negative=args.negative)
    gen_s = time.time() - t

    if args.native or args.upscale <= render:
        out.write_bytes(png)
        say(f"{render}x{render} in {gen_s:.1f}s -> {out}")
    else:
        raw = out.with_suffix(f".{render}.png")
        raw.write_bytes(png)
        t = time.time()
        upscale(raw, out, args.upscale)
        up_ms = (time.time() - t) * 1000
        if not args.keep_source:
            raw.unlink()
        say(f"{render}x{render} in {gen_s:.1f}s + Lanczos->{args.upscale} in "
            f"{up_ms:.0f}ms -> {out}")

    print(out)


def main():
    p = argparse.ArgumentParser(prog="imagegen", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("-v", "--verbose", action="store_true",
                   help="report lifecycle steps, not just the outcome")
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("gen", help="render an image (starts the server if needed)")
    g.add_argument("prompt")
    g.add_argument("-o", "--out", required=True, help="output PNG path")
    g.add_argument("--size", type=int, default=512, help="render resolution (default 512)")
    g.add_argument("--upscale", type=int, default=1024,
                   help="Lanczos target; <= --size disables (default 1024)")
    g.add_argument("--native", action="store_true",
                   help="no upscale — render at --size and stop")
    g.add_argument("--steps", type=int, help="sampler steps (server default 26)")
    g.add_argument("--seed", type=int, help="fixed seed; the server default is deterministic")
    g.add_argument("--negative", help="negative prompt")
    g.add_argument("--keep-source", action="store_true", help="keep the pre-upscale PNG")
    g.set_defaults(func=cmd_gen)

    u = sub.add_parser("up", help="evict the LLM, start sd-server, pre-warm")
    u.add_argument("--no-prewarm", dest="prewarm", action="store_false")
    u.set_defaults(func=lambda a: (up(prewarm=a.prewarm),
                                   say(f"ready; {vram_used() / 1024**3:.2f} GiB in use")))

    d = sub.add_parser("down", help="stop sd-server, give the card back to llama-swap")
    d.set_defaults(func=lambda a: down())

    s = sub.add_parser("status", help="card usage and server state")
    s.set_defaults(func=lambda a: print(
        f"{CARD}: {vram_used() / 1024**3:.2f} GiB used\n"
        f"container: {'running' if container_running() else 'stopped'}\n"
        f"server: {'ready' if server_ready() else 'not responding'}"))

    args = p.parse_args()
    global VERBOSE
    VERBOSE = args.verbose
    try:
        args.func(args)
    except subprocess.CalledProcessError as e:
        raise SystemExit(f"imagegen: {' '.join(e.cmd)} failed:\n{e.stderr.strip()}")


if __name__ == "__main__":
    main()
