# Pricing, disks, and zone checks

Procedure checked against official documentation on 2026-11-03. Re-fetch prices and support for the requested location; don't treat the examples as an evergreen price list.

## Price the actual configuration

Use [general-purpose VM prices](https://cloud.google.com/products/compute/pricing/general-purpose), [storage-optimized VM prices](https://cloud.google.com/products/compute/pricing/storage-optimized), and [disk pricing](https://cloud.google.com/compute/disks-image-pricing). Select the requested region and currency explicitly. In extracted pages, verify the region heading, consumption model, column labels, and units around each number. Do not pick the first number matching a machine name from a multi-region table.

Record for each candidate: exact type, region, currency, consumption model, effective/retrieval date, CPU and memory quantities/rates or exact predefined VM price, mandatory Local SSD quantity/rate, and whether that disk charge is included. Keep source URLs and SKU identifiers when the source provides them.

Local SSD attached automatically is not necessarily included in every displayed compute price. The named C4/C4D “with Local SSD” and Z-series configuration rows in the linked pricing pages include their listed SSD allocation. Use those configuration prices once; don't add generic Local SSD charges again. For resource-only quotes, price mandatory SSD separately using the matching series' rates.

For machine series priced by resources:

```text
compute_hourly = vCPUs × CPU_hourly_rate + billable_RAM × RAM_hourly_rate
local_hourly   = attached_SSD_capacity × matching_series_SSD_hourly_rate
node_monthly   = 730 × (compute_hourly + local_hourly) + required_network_disk_monthly
```

Prefer an exact predefined price when available. Custom shapes, extended memory, bare metal, premium OS, and nondefault consumption models may have different rates. Match the billable resource units, not a rounded marketing description.

For repeatable programmatic pricing, use the [Cloud Billing Catalog API](https://cloud.google.com/billing/docs/reference/rest/v1/services.skus/list). Compute Engine service ID is `6F81-5844-456A`. The API requires appropriate credentials/API access; don't assume anonymous access. Follow every `nextPageToken`. Filter by service region, resource/series, on-demand usage, currency, and applicable effective time. Inspect `pricingExpression.usageUnit`, tier start amounts, and `unitPrice.units + unitPrice.nanos / 1e9`. A substring match alone is not enough to identify a SKU. Missing/ambiguous SKUs are a failed quote, never a zero price. Don't print access tokens or enable APIs to make a lookup work.

Public list prices and account-specific effective prices answer different questions. Use private billing data only when requested and authorized; never save it in this skill.

## Hyperdisk calculation

Sources: [Hyperdisk overview](https://docs.cloud.google.com/compute/docs/disks/hyperdisks), [Balanced limits](https://docs.cloud.google.com/compute/docs/disks/hd-types/hyperdisk-balanced), [per-instance limits](https://docs.cloud.google.com/compute/docs/disks/hyperdisk-perf-limits), and [disk pricing](https://cloud.google.com/compute/disks-image-pricing).

For an ordinary standalone Hyperdisk Balanced volume, using monthly rates:

```text
monthly = GiB × capacity_rate
        + max(0, provisioned_IOPS - 3000) × IOPS_rate
        + max(0, provisioned_MiBps - 140) × throughput_rate
```

The included baseline is 3,000 IOPS and **140 MiB/s**, not AWS gp3's 125 MiB/s. Defaults can exceed the included baseline: never assume omitted performance settings are free. These formulas are not storage-pool pricing.

As checked on 2026-11-03, ordinary Balanced volumes support 4 GiB–64 TiB. At 4/5 GiB, IOPS is fixed at 2,000/2,500. At 6 GiB and above:

```text
3000 <= IOPS <= min(500 × size_GiB, 160000)
max(140, IOPS / 256) <= throughput_MiBps <= min(2400, IOPS / 4)
```

Check rounding and special previews in the current docs. The effective cap is also bounded by the VM's aggregate disk limits (including other attached disks). Read and write share Hyperdisk IOPS/throughput limits; advertised Local SSD read and write maxima aren't a combined guarantee.

Other types:

| Type | Billable components | Selection rule |
|---|---|---|
| Balanced HA | Capacity, IOPS, throughput under its own rates | Cross-zone synchronous disk replication; don't use ordinary Balanced rates unchanged |
| Extreme | Capacity + provisioned IOPS | High random-I/O requirements; throughput derives from IOPS; verify minimum machine size |
| Throughput | Capacity + provisioned throughput | Large sequential workloads; HDD-like latency profile; IOPS derives from throughput |
| ML | Capacity + provisioned throughput | High read throughput / shared read-only datasets, not the default transactional DB disk |

Examples of Extreme eligibility constraints: C4 needs at least 96 vCPUs; C4D/C4A need at least 64. Therefore it is not a valid upgrade for `c4d-highmem-16`. The Z4D attachment tables also show zero Extreme disks for both 8-highlssd and 16-standardlssd. Re-check constraints for the exact series and size.

Use GiB/TiB for capacity when the source does; preserve GB versus GiB labels if ambiguous. `1000 MiB/s ≈ 8.39 Gbps`. Don't compare a network Gbps limit directly with disk MiB/s.

## Region and zone offering

Prerequisites: installed `gcloud`, an already authorized identity, and a user-selected project with Compute API access. The commands below only read. Run with a bounded tool timeout; stop on authentication, permission, or disabled-API errors. Don't start interactive login, change configuration, or enable an API.

Use shell variables with concrete user-selected values. These examples work in Bash and zsh:

```bash
PROJECT='your-project-id'
REGION='us-central1'
ZONE='us-central1-a'
TYPE='z4d-highmem-8-highlssd'

gcloud compute zones describe "$ZONE" --project="$PROJECT" \
  --format='json(name,region,status)' --quiet

gcloud compute machine-types describe "$TYPE" --zone="$ZONE" \
  --project="$PROJECT" \
  --format='json(name,zone,guestCpus,memoryMb,architecture,bundledLocalSsds,isSharedCpu,deprecated)' --quiet
```

Check the returned region matches the requested region. Successful machine-type lookup proves that exact type is in that zone's catalog. It does not guarantee allocation. Missing optional fields (such as architecture in an older SDK) are unknown; resolve them from official series documentation. `memoryMb / 1024` is the usual GiB normalization of the Compute machine-type memory field; retain the raw value and API units when reconciling a documentation discrepancy.

To find alternatives in one zone:

```bash
gcloud compute machine-types list --zones="$ZONE" --project="$PROJECT" \
  --filter="name~'^(c4|c4d|c4a|n4|n4d|n4a|z3|z4d|z4m)-'" \
  --format='table(name,guestCpus,memoryMb,zone.basename(),deprecated.state)' --quiet
```

For region-wide coverage, enumerate zones first, then use that exact list. This avoids treating one zone as representative of its region:

```bash
gcloud compute zones list --project="$PROJECT" \
  --filter="name~'^${REGION}-[a-z]+$'" \
  --format='table(name,status)' --quiet
```

Inspect the returned zone names, then query them with `--zones='zone-a,zone-b,zone-c'`. Use an exact `name=...` filter for the final selected type. Include explicit missing rows for requested zones, rather than silently dropping them. If a filter behaves unexpectedly, inspect the returned fields and filter locally; never interpret a failed query as absence.

[Machine-type list CLI](https://docs.cloud.google.com/sdk/gcloud/reference/compute/machine-types/list) · [Machine-type API schema](https://docs.cloud.google.com/compute/docs/reference/rest/v1/machineTypes) · [Regions and zones](https://docs.cloud.google.com/compute/docs/regions-zones)

The machine-types API can expose `bundledLocalSsds.partitionCount` and `defaultInterface`, but it is not a complete disk configurator. Verify disk capacity, performance, allowed attachment combinations, Hyperdisk support, and boot requirements in the family and disk docs. A disk-type catalog entry alone doesn't prove compatibility with the VM.

## Quota, access, and capacity are separate

With project inspection authorized, inspect regional quota without retrieving unrelated configuration:

```bash
gcloud compute regions describe "$REGION" --project="$PROJECT" \
  --format='json(name,status,quotas)' --quiet
```

Also check project-wide quotas with `gcloud compute project-info describe --project="$PROJECT" --format='json(quotas)' --quiet`. Check applicable family CPU quotas, Local/Titanium SSD capacity quotas, and Hyperdisk capacity/IOPS/throughput quotas, including consumption-model differences. Some newer or zonal quotas require the Cloud Quotas service/console; the regional quota response alone is not a complete clearance. Preview access and image architecture are separate constraints too.

Return this distinction explicitly:

| Check | Evidence | What it proves |
|---|---|---|
| Zone offering | Exact machine-types response plus current docs | Type is catalogued in the zone |
| Project eligibility | IAM/API access, applicable quota headroom, preview access | Necessary permissions and limits appear sufficient |
| Allocatable capacity now | Separate capacity evidence, or authorized allocation result | Catalog and quota alone cannot establish it |

Use `unknown/not tested` for capacity unless separately verified. Existing reservation evidence can help only when its shape, zone, free count, ownership/access, and consumption conditions match. Never create a reservation or VM as an implicit availability probe.
