---
name: jvm-heapdump
description: Investigate JVM memory leaks using class histograms, heap dumps, and retained-object analysis. Use for growing post-GC heap, suspected object retention, or heap captures that fail under container memory or disk limits. Covers local processes and JVMs in containers or Kubernetes.
---

# JVM memory-leak investigation

Use `jcmd` for HotSpot-compatible JVMs. For other runtimes, establish the vendor's equivalent commands and dump format first. A heap dump diagnoses Java object retention, not every cause of process-memory growth.

Histogram collection and heap capture can pause the application or trigger collection. Full dumps also write large sensitive files and can exhaust memory or disk. Obtain explicit approval for the process, capture method, destination, retention, and cleanup before capturing a shared workload.

## Establish the memory problem

Compare post-GC heap at comparable workload states, not arbitrary peaks. Record workload volume, cache warm-up, JVM uptime/revision, heap usage, process RSS, and container memory usage where applicable.

If RSS or cgroup usage grows while post-GC heap is stable, investigate native allocations, direct buffers, thread stacks, metaspace, mapped files, or page cache before taking another heap dump. `jcmd "$pid" VM.native_memory summary` is useful only when Native Memory Tracking was enabled at JVM startup; it does not account for all process memory. Restarting with different JVM flags requires separate approval.

## Pre-flight

Verify the exact host/process identity and JVM version; do not assume PID 1. Run as the process owner with compatible JDK tools in the same PID/filesystem namespace. Confirm attachment is permitted and inspect the target's supported commands:

```zsh
jcmd "$pid" VM.version
jcmd "$pid" help GC.class_histogram
jcmd "$pid" help GC.heap_dump
jcmd "$pid" GC.heap_info
```

Check free disk space, expected dump size, memory headroom, filesystem ownership, allowable application pause, and any watchdog or liveness budget. On Linux containers, resolve the process's actual cgroup; do not assume the cgroup-v2 files are mounted at the root. Check both usage and limits.

Heap dumps can contain credentials, tokens, request payloads, and personal data. Use an approved private directory accessible to the JVM owner, with restrictive directory and file permissions. Never add artifacts to a repository or quote heap contents into chat.

For a local JVM running as the current user:

```zsh
umask 077
out=/approved/private/artifact/directory
mkdir -p "$out"
chmod 700 "$out"
ts=$(date -u +%Y%m%dT%H%M%SZ)
```

For a different service user, provision the directory for that user instead; the caller's umask does not control files created by the target JVM.

## Start with comparable histograms

```zsh
jcmd "$pid" GC.class_histogram > "$out/histogram-$ts.txt"
```

This is a high-impact operation, not a cheap sampling loop. Keep capture intervals bounded and workload states comparable. Inspect runtime help before changing options: including unreachable objects changes the meaning of the comparison.

Resolve `scripts/compare_histograms.py` relative to this skill directory, then compare the exact files:

```zsh
uv run --quiet python /absolute/skill/directory/scripts/compare_histograms.py \
  /path/to/earlier.txt /path/to/later.txt
```

The script reports changes in instance counts and shallow bytes by class. These are not retained sizes. Persistent class growth after collection suggests retention; it does not establish the retaining owner or prove a leak rather than an intentional cache.

## Capture and preserve a heap dump

Prefer approved, sufficiently large, fast local storage over a slow network filesystem. Dump writes can populate page cache charged to a container's memory limit; dirty pages cannot be discarded before writeback. A capture can therefore OOM-kill a container without Java heap growth. A long JVM pause can also exceed a watchdog or liveness budget.

1. Recheck identity, memory headroom, disk capacity, and pause budget immediately before capture. Choose a new absolute path on the target filesystem; do not overwrite an existing artifact.

```zsh
heap_path="$out/heap-$ts.hprof"
jcmd "$pid" GC.heap_dump "$heap_path"
```

On supported HotSpot versions, the default requests a full GC and dumps live objects. Confirm the exact runtime help rather than assuming options or pause behaviour across versions. Restrict the resulting file to the approved owner before transfer.

2. Check command success, a non-empty stable file size, and the HPROF header. A header beginning `JAVA PROFILE` is a sanity check, not proof of a complete or parseable dump. Open it successfully with an appropriate analyzer before claiming capture integrity.

3. If transfer is needed, copy to approved restricted storage and compare complete SHA-256 hashes before deleting the source. Budget disk space and memory headroom for transfer too. Direct I/O is an optional optimization only after testing support and alignment on the actual filesystems; do not assume it works or rely on it to make unsafe capture safe.

4. Remove the source only after successful verification and explicit cleanup approval. Report any partial or duplicate artifacts and who owns retention.

### Container and Kubernetes targets

Run the same JVM commands inside the target namespace, for example:

```zsh
kubectl --context "$context" -n "$namespace" exec "$pod" -c "$container" -- \
  jcmd "$pid" GC.class_histogram > "$out/histogram-$ts.txt"
kubectl --context "$context" -n "$namespace" exec "$pod" -c "$container" -- \
  jcmd "$pid" GC.heap_dump "$heap_path"
```

The histogram redirection is local to the caller; `heap_path` must be an approved absolute path inside the container. Check that PID, tools, permissions, disk capacity, memory limits, and liveness budget belong to that exact container. Creating a debug container or changing probes, mounts, limits, or storage settings requires a separate plan and approval.

## Find the retaining owner

Analyze the dump on a restricted machine with sufficient RAM and scratch space; required capacity depends on the dump and analyzer. In Eclipse MAT or an equivalent tool:

- Rank the dominator tree by retained size, not just object counts or shallow size.
- Follow paths to GC roots for the growing objects; identify the collection, cache, thread, classloader, or listener retaining them.
- Check whether retention matches expected workload and lifecycle bounds. A large object graph or a leak-suspect report alone is not proof.
- Propose a targeted lifecycle/bounds fix and a regression test; verify post-GC memory stabilizes under the same workload before claiming the leak is fixed.

Stop if identity changes, the process restarts, headroom or storage is insufficient, tooling is unavailable, or capture would require unapproved service changes. Do not keep retrying a dangerous capture.

Report artifact location, size/hash, JVM/process identity and revision, comparable capture intervals/workload, observed pauses/restarts, retaining paths, uncertainty, and cleanup/retention status. Never expose raw heap contents.

Command reference: [Oracle JDK 21 jcmd](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jcmd.html). The target JVM's `jcmd help` remains authoritative for its supported commands.
