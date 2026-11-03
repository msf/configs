# GCP machine map

Verified against official pages on **2026-11-03**. Refresh for a deployment decision. This is a shortlist guide, not an exhaustive catalog or a performance benchmark.

## Translate AWS intuition

| AWS intuition | GCP starting point | Important difference |
|---|---|---|
| c-family, roughly 2 GiB/vCPU | `*-highcpu-*` | RAM shape is separate from series |
| m-family, roughly 4 GiB/vCPU | `*-standard-*` | C4 is general-purpose despite the C |
| r-family, roughly 8 GiB/vCPU | `*-highmem-*` | Exact usable RAM can be lower than the nominal ratio |
| Graviton / arm64 | C4A or N4A (Axion); older T2A (Ampere) | Arm vCPU is a physical core |
| Recent AMD x86 for value | N4D without local disk; compare C4D for performance/local disk | D means AMD, not disk |
| General-purpose instance with local NVMe | Selected C4/C4D/C4A `-lssd` | Fixed disk quantity depends on exact shape |
| Storage-optimized i-family | Z3, Z4D, Z4M | Different SSD densities and minimum purchases |

C4/N4/Z4 are the newest generations in these series in the inspected catalog. No N6 is documented there. C4D/N4D/Z4D use **5th-gen EPYC Turin**, not a CPU called “generation 4.” C4 can even use **6th-gen Xeon Granite Rapids**. Series generations and CPU generations are different counters.

## Vendor, architecture, and RAM

RAM/vCPU below is `highcpu / standard / highmem`, using 16-vCPU shapes. Other sizes can differ: always quote exact RAM for the selected type.

| Series | CPU platform | Architecture | vCPUs/core by default | RAM GiB/vCPU | Local SSD |
|---|---|---|---:|---|---|
| C4 | Xeon Emerald Rapids or Granite Rapids | x86-64 | 2 | 2 / 3.75 / 7.75 | Selected `-lssd`; all C4 `-lssd` use Granite Rapids |
| C4D | EPYC Turin | x86-64 | 2 | 1.875 / 3.875 / 7.875 | Selected `-lssd` |
| C4A | Axion, Neoverse V2 | arm64 | 1 | 2 / 4 / 8 | Selected `-lssd` |
| N4 | Xeon Emerald Rapids | x86-64 | 2 | 2 / 4 / 8 | No |
| N4D | EPYC Turin | x86-64 | 2 | 2 / 4 / 8 | No |
| N4A | Axion, Neoverse N3 | arm64 | 1 | 2 / 4 / 8 | No |
| Z3 | Xeon Sapphire Rapids | x86-64 | 2 | Highmem: 8 | Mandatory Titanium SSD |
| Z4D | EPYC Turin | x86-64 | 2 | Highmem: 7.875 | Mandatory Titanium SSD |
| Z4M | Xeon Emerald Rapids | x86-64 | 2 | Highmem: 7.625 at 16 vCPUs | Mandatory Titanium SSD |

N4/N4D/N4A support custom shapes; C/Z choices here are predefined. C3/C3D remain useful previous-generation comparators (Sapphire Rapids/Genoa). Older T2D uses EPYC Milan but **one vCPU per physical core**, an important exception to the x86 SMT rule. T2A uses Ampere Altra; neither T2 family supports Local SSD. H4D is an AMD HPC specialist with one vCPU per core, not a default small database choice. C4N is network-optimized. For RAM beyond roughly 8 GiB/vCPU, inspect custom-memory limits and the memory-optimized families rather than forcing a highmem shape.

Sources: [machine families](https://docs.cloud.google.com/compute/docs/machine-resource), [CPU platforms](https://docs.cloud.google.com/compute/docs/cpu-platforms), [general-purpose shapes](https://docs.cloud.google.com/compute/docs/general-purpose-machines), [storage-optimized shapes](https://docs.cloud.google.com/compute/docs/storage-optimized-machines).

Google's [pricing documentation](https://cloud.google.com/products/compute/pricing/storage-optimized) explicitly defines its memory “GB” as binary JEDEC GB/GiB. Its pricing tables label RAM GiB, resolving the shorter “GB” label in machine documentation. Don't round 63/126 GiB up to 64/128 GiB for workload fit.

## Exact local-storage examples

| Exact type | vCPUs | RAM GiB | Local SSD count × GiB | SSD GiB/vCPU |
|---|---:|---:|---|---:|
| `n4d-highmem-16` | 16 | 128 | None; unsupported | 0 |
| `c4-highmem-16-lssd` | 16 | 124 | 2 × 375 | 46.875 |
| `c4d-highmem-16-lssd` | 16 | 126 | 1 × 375 | 23.4375 |
| `c4a-highmem-16-lssd` | 16 | 128 | 4 × 375 | 93.75 |
| `z3-highmem-16-highlssd` | 16 | 128 | 2 × 3,000 | 375 |
| `z4d-highmem-16-standardlssd` | 16 | 126 | 1 × 3,500 | 218.75 |
| `z4d-highmem-8-highlssd` | 8 | 63 | 1 × 3,500 | 437.5 |
| `z4d-highmem-16-highlssd` | 16 | 126 | 2 × 3,500 | 437.5 |
| `z4m-highmem-16` | 16 | 122 | 1 × 14,000 | 875 |

`z3-highmem-16` is an incomplete name: the documented 16-vCPU option is `z3-highmem-16-highlssd`. Z3 standardlssd starts at 14 vCPUs with 3,000 GiB. Don't compare an invented Z3 shape with a real N4D shape.

**Z4D 8-highlssd versus 16-standardlssd:** same 3,500 GiB total local storage; half the CPU and RAM; twice the storage per vCPU. Both list 650,000 read / 512,000 write IOPS and 3,150 read / 2,400 write MiB/s. These are published disk limits, not DB measurements. Eight vCPUs are four physical cores under default SMT.

Z4D highlssd has twice the disk capacity of standardlssd at the same vCPU count. Z3 ratios vary by shape; don't impose Z4D's regular ratios on it. Z4M offers still higher capacity density but may cost more per node. Bare-metal disk sizes/topology differ from VM variants.

For comparison, Z3 16-highlssd lists 1.5M read IOPS against Z4D 16-highlssd's 1.3M. “Newer” is not “better on every metric.” Check capacity, read/write performance, latency, endurance, CPU generation, and cost independently.

Sources: [C/N shape tables](https://docs.cloud.google.com/compute/docs/general-purpose-machines), [Z shape and disk-performance tables](https://docs.cloud.google.com/compute/docs/storage-optimized-machines).

## Dated price example: Iowa, USD on-demand

Fetched **2026-11-03**, `us-central1`, public default/on-demand prices, no discounts. Local SSD rows below are **configuration totals including the listed local SSD**. Boot disks, other Hyperdisks, network, backups, licenses, and tax are excluded. Use 730 hours only for planning conversion. Re-fetch before quoting current prices.

| Type | RAM GiB | Local SSD GiB | Configuration $/hour |
|---|---:|---:|---:|
| `n4a-highcpu-16` | 32 | 0 | 0.51968 |
| `n4d-highcpu-16` | 32 | 0 | 0.57168 |
| `n4a-highmem-16` | 128 | 0 | 0.80864 |
| `n4d-highmem-16` | 128 | 0 | 0.88944 |
| `n4-highmem-16` | 128 | 0 | 0.95216 |
| `c4d-highmem-16` | 126 | 0 | 0.996177886 |
| `c4d-highmem-16-lssd` | 126 | 375 | 1.078369667 |
| `c4-highmem-16-lssd` | 124 | 750 | 1.207095562 |
| `z4d-highmem-8-highlssd` | 63 | 3,500 | 1.264345753 |
| `z4d-highmem-16-standardlssd` | 126 | 3,500 | 2.145129863 |
| `z4d-highmem-16-highlssd` | 126 | 7,000 | 2.528691507 |
| `z4m-highmem-16` | 122 | 14,000 | 3.287109973 |

Useful conclusions **within this sample**, not a global price/performance ranking:

- Without local disk, N4A is an Arm value candidate; N4D is an AMD x86 value candidate. N4D highmem is about 6.6% cheaper than N4 highmem. Actual throughput per dollar remains unmeasured.
- N4A/N4D highcpu cost $0.03248/$0.03573 per vCPU-hour for the whole VM. Highmem costs $0.0063175/$0.00694875 per GiB-RAM-hour for the whole VM. Those aren't marginal CPU/RAM SKU rates.
- Z4D 8-highlssd is about $923 per 730 hours versus $1,566 for 16-standardlssd: 41.1% cheaper for equal SSD capacity, with half the CPU/RAM.
- Whole configuration cost per raw SSD GiB-month is about $0.264 for Z4D highlssd versus $0.171 for Z4M-16. Z4M's roughly $2,400 monthly minimum here buys 14,000 GiB; it doesn't save money if only 3,500 GiB is needed.

Sources: [general-purpose prices](https://cloud.google.com/products/compute/pricing/general-purpose), [storage-optimized prices](https://cloud.google.com/products/compute/pricing/storage-optimized). Tables use the public default price column; storage-optimized on-demand consumption model ID: `7754-699E-0EBF`. No invoice SKU decomposition or private effective price was verified.

## Database starting points

Use N4D/N4A plus Hyperdisk Balanced when inexpensive CPU/RAM and durable network block storage fit. Compare C4D/C4A when their performance or small local disk allocation matters. Consider Z4D when multi-TiB local storage is an actual requirement, and Z4M when still higher storage density fits the dataset and budget. Include the cost of replicas and recovery infrastructure before comparing these with a durable-disk design.
