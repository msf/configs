---
name: gcp-machines
description: Compare Google Cloud Compute Engine machine types, CPU generations and architectures, RAM/vCPU and Local SSD/vCPU ratios, regional prices, and Hyperdisk configurations. Use for GCP instance selection, AWS-to-GCP equivalents, cheapest CPU/RAM/local NVMe, AMD EPYC versus Intel versus Arm, C4/C4D/C4A/N4/N4D/N4A/Z3/Z4D comparisons, or machine availability in a region and zone.
---

# GCP machine selection

Turn a workload requirement into a short, priced shortlist. Use official Google Cloud documentation and live read-only catalog queries. Never infer a winner from a family name or CPU vendor.

## Workflow

1. Establish the constraints: region, zone(s), architecture, minimum usable RAM, CPU needs, disk capacity, random IOPS versus sequential throughput, and durability. Ask only for missing inputs that change the answer. For a conceptual question, proceed with explicit assumptions instead of blocking on a questionnaire.
2. Read [the machine map](references/machine-map.md). Select at most four relevant candidates. Verify exact shapes, CPU platforms, disk counts, and machine-level I/O limits against current family docs. Treat the reference as a dated starting point, not a permanent catalog.
3. Read [pricing and availability](references/pricing-availability.md). Fetch comparable regional prices and check each requested zone. Reject incompatible candidates before ranking them. If no region was given, an explicitly labeled `us-central1`, USD, Linux on-demand example is acceptable; it is not a quote for the user's deployment.
4. Lead with the recommendation and its deciding constraint. Show a compact comparison, the assumptions, sources and retrieval date, and what remains unverified. For a database, include the storage failure/recovery model before recommending Local SSD.

## Mental model

- Separate **series**, **CPU vendor/architecture**, **memory shape**, and **storage variant**. `c4d-highmem-16-lssd` encodes four independent choices.
- GCP's C4 is a performance-oriented **general-purpose** series. `highcpu`, `standard`, and `highmem` choose the RAM ratio within it; AWS's c/m/r distinction doesn't map to GCP's C/N/Z letters.
- `D` in these GCP series means AMD, not disk. `A` in C4A/N4A means Google Axion Arm. T2A is Ampere Arm. `amd64`/`x86_64` includes both AMD and Intel; it is not an AMD vendor filter.
- `-lssd`, `-standardlssd`, and `-highlssd` describe storage variants. Some older series attach Local SSD without a name suffix. Verify the exact series rules.
- Generation numbers are local to a series; don't invent N6, extrapolate a missing shape, or assume that every shape/zone of a newer generation has launched. Include preview status and access restrictions where relevant.
- A vCPU is not a portable performance unit. Record SMT/thread semantics; Arm cores and x86 SMT threads aren't interchangeable. Rank measured workload throughput per dollar separately from sticker price per vCPU.

## What does “best value” mean?

Report the relevant normalized costs, with the numerator named:

```text
RAM ratio                 = RAM GiB / vCPUs
Local SSD ratio           = raw Local SSD GiB / vCPUs
VM dollars/vCPU-hour      = full VM compute hourly price / vCPUs
VM dollars/GiB-RAM-hour   = full VM compute hourly price / RAM GiB
node dollars/GiB-SSD-month = (VM + mandatory Local SSD + required disks) monthly / usable SSD GiB
workload value            = measured useful work / total cost
```

The full-VM ratios allocate all compute cost to one resource. They are **not** marginal CPU or RAM SKU rates. Show marginal rates separately if useful. Avoid declaring a RAM winner whose CPU count or required disk makes the actual workload more expensive.

For storage, distinguish the Local SSD **line-item rate** from the cost of the **whole node needed to obtain it**. Fixed disk quantities can make a cheap disk rate an expensive deployment. Use usable capacity after replication, RAID, free-space reserve, and compaction headroom when specified; otherwise label capacity raw. Do not silently assume a replication factor.

Default pricing basis: public USD on-demand Linux, no Spot, CUD, sustained-use assumption, private discount, premium OS, or tax. Keep alternative purchasing models separate. Convert hours to months with 730 hours only as an explicit planning convention.

## Database and disk checks

- Local SSD is host-local, ephemeral storage. Require a stated replication/rebuild/backup design if it holds authoritative data. A single node's RAID doesn't protect against loss of the host. Do not describe all restarts or maintenance as guaranteed loss: check the documented lifecycle and recovery behavior.
- Compare Local SSD against a valid Hyperdisk configuration, not capacity alone. Price capacity, provisioned IOPS, and provisioned throughput; then check per-volume limits, aggregate VM limits, supported disk types, and minimum machine sizes.
- Hyperdisk Balanced is the first network-block comparison for ordinary databases. Throughput targets large sequential I/O and isn't a substitute for low-latency random I/O. Extreme needs an eligible machine size; never suggest it merely because the family name appears in a support table.
- Check boot-disk support separately. Newer series can require Hyperdisk rather than legacy Persistent Disk. Include required boot storage in deployment totals or state its exclusion.
- Record latency requirements, write endurance where documented, network bandwidth for replication, and recovery time if these decide between C-series and storage-optimized Z-series.

## Evidence and safety

Use current official machine, CPU, disk, pricing, and region/zone sources linked in the references. Search snippets and marketing price-performance claims aren't measured workload results. If a source cannot be acquired, say which facts remain unverified rather than supplying remembered prices.

Read-only by default. Never create a VM, reservation, disk, quota request, billing/API enablement, or credentials to test availability. Use the user-selected project explicitly; don't change the active gcloud configuration or infer a project from unrelated work. Ask before authentication changes. Never emit tokens or private pricing agreements.

Report availability in separate fields: **catalog offering**, **project quota/access**, and **current allocatable capacity**. A successful machine-types lookup proves only the first. IAM/auth/API failures are not proof of an unsupported machine. Mark missing checks as unknown.

## Answer shape

For a detailed comparison, use:

`exact type | CPU / architecture | vCPU / RAM GiB | Local SSD count × GiB | compute + disk $/h | relevant normalized cost | zone evidence`

Follow with the deciding trade-off and one unresolved question, if any. For a naming question, give the mental map without a pricing investigation. Do not enumerate the entire GCP catalog when three candidates answer the question.
