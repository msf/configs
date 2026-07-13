---
name: aws-pricing
description: Calculate AWS EC2, EBS gp3, S3 request, and instance-vs-EBS costs from official AWS public price files and EC2 instance metadata. Use when pricing AWS instances, EBS volumes, S3 request rates, cluster OPEX, region-specific on-demand rates, or checking whether local NVMe instance families are cheaper than EBS-backed equivalents.
---

# AWS Pricing

Use this skill for AWS infrastructure pricing. Prefer official AWS data over memory or third-party pages.

## Ground rules

- Use region-specific AWS Price List bulk files as the primary price source:
  - EC2 + EBS: `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/<region>/index.json`
  - S3: `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/<region>/index.json`
- Use `aws ec2 describe-instance-types --region <region>` for instance specs, local NVMe size, and EBS bandwidth/IOPS caps.
- EC2 default filter for Dune pricing: Linux, Shared tenancy, On-Demand, no preinstalled software, capacity status `Used`.
- Always report SKU and rate code for audited numbers when a price becomes a decision input.
- Do not use Reserved Instances, Savings Plans, Spot, private discounts, or blended Cost Explorer rates unless the user explicitly asks.
- State whether values are verified from AWS APIs/price files or inferred from formulas.

## Helper CLI

Run from this skill directory or use the absolute path:

```bash
python3 ~/.pi/agent/skills/aws-pricing/scripts/aws-pricing.py ec2 --region eu-west-1 m8gd.8xlarge m8g.8xlarge
python3 ~/.pi/agent/skills/aws-pricing/scripts/aws-pricing.py gp3 --region eu-west-1 --size-gb 500 --iops 5000 --throughput-mibps 1000
python3 ~/.pi/agent/skills/aws-pricing/scripts/aws-pricing.py s3-get --region eu-west-1 --requests 10000000
python3 ~/.pi/agent/skills/aws-pricing/scripts/aws-pricing.py parity --region eu-west-1 --with-local m8gd.24xlarge --ebs-only m8g.24xlarge --size-gb 5700 --throughput-mibps 2000
```

The script caches official price files under `~/.cache/pi-aws-pricing/`. Add `--refresh` before the subcommand to refetch:

```bash
python3 ~/.pi/agent/skills/aws-pricing/scripts/aws-pricing.py --refresh ec2 --region eu-west-1 m8gd.24xlarge
```

## Official fetch recipes

### EC2 prices from public bulk file

```bash
REGION=eu-west-1
curl -sS "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/${REGION}/index.json" -o /tmp/ec2-${REGION}.json
```

Find an instance price by filtering products where:

```text
attributes.instanceType == <instance>
attributes.operatingSystem == Linux
attributes.tenancy == Shared
attributes.preInstalledSw == NA
attributes.capacitystatus == Used
terms.OnDemand[sku].priceDimensions[].unit == Hrs
```

### EBS gp3 prices from the EC2 price file

EBS lives in the AmazonEC2 offer. For gp3 use `usagetype` suffixes:

```text
VolumeUsage.gp3          # storage, usually unit GB-Mo
VolumeP-IOPS.gp3         # provisioned IOPS above baseline, unit IOPS-Mo
VolumeP-Throughput.gp3   # provisioned throughput above baseline, often unit GiBps-mo
```

If AWS reports gp3 throughput as `GiBps-mo`, divide by `1024` to get `$ / MiB/s-month`.

### Instance specs and EBS caps

```bash
aws ec2 describe-instance-types \
  --region eu-west-1 \
  --instance-types m8g.24xlarge m8gd.24xlarge \
  --query 'InstanceTypes[].{InstanceType:InstanceType,EbsInfo:EbsInfo.EbsOptimizedInfo,Storage:InstanceStorageInfo,Network:NetworkInfo.NetworkPerformance}' \
  --output json
```

Use this to verify:
- local NVMe count and size (`InstanceStorageInfo`)
- EBS optimized throughput / bandwidth / IOPS caps (`EbsInfo.EbsOptimizedInfo`)
- advertised network bandwidth (`NetworkInfo.NetworkPerformance`)

## gp3 formula

gp3 included baseline:

```text
3,000 IOPS
125 MiB/s throughput
```

Monthly cost:

```text
storage_cost     = size_gb * storage_price_per_gb_month
extra_iops_cost  = max(iops - 3000, 0) * price_per_iops_month
extra_thr_cost   = max(throughput_mibps - 125, 0) * price_per_mibps_month
total_monthly    = storage_cost + extra_iops_cost + extra_thr_cost
hourly           = total_monthly / 730
```

Common gp3 limits:

```text
size:        1 GiB .. 64 TiB
IOPS:        up to 80,000
throughput:  up to 2,000 MiB/s
IOPS density: up to 500 IOPS/GiB
throughput ratio: throughput MiB/s <= 0.25 * provisioned IOPS
```

Also check the EC2 instance's EBS caps. A volume can be provisioned above what the instance can use.

## Unit discipline

- AWS gp3 throughput is in `MiB/s`; network marketing bandwidth is usually decimal `Gbps`.
- `1000 MiB/s` is about `8.39 Gbps`, not `1 Gbps`.
- gp3 max `2000 MiB/s` is about `16.78 Gbps`.
- EC2 instance storage is listed as GB in AWS APIs. Don't silently change GB/GiB in pricing tables; state the unit used.

## Dune conventions

- Use `730` hours/month for quick monthly conversion unless finance provides another convention.
- If the org has a negotiated AWS discount, apply it as a final multiplier after EC2/S3/EBS-style components. Keep AWS list price and discounted OPEX separate. (The actual discount factor is confidential — keep it in a local note, not here.)
- For customer-facing proposals, include required coordinators/control-plane storage in OPEX even if worker sticker specs exclude them.

## Answer shape

When returning pricing, include:

1. region and price basis (`eu-west-1`, Linux Shared On-Demand, public list price)
2. exact AWS unit prices with SKU/rate code when material
3. formulas and arithmetic
4. instance EBS caps when comparing EBS to local NVMe
5. verified vs inferred caveats
