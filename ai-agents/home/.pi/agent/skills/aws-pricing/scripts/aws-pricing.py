#!/usr/bin/env python3
"""Small AWS public-pricing helper for EC2 and EBS gp3.

Uses official AWS bulk price files. Instance specs/EBS caps optionally come from
`aws ec2 describe-instance-types` when the AWS CLI is installed and configured.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request
from decimal import Decimal, getcontext
from pathlib import Path
from typing import Any

getcontext().prec = 28

PRICE_ROOT = "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws"
CACHE_DIR = Path(os.environ.get("PI_AWS_PRICING_CACHE", "~/.cache/pi-aws-pricing")).expanduser()
HOURS_PER_MONTH = Decimal(os.environ.get("PI_AWS_PRICING_HOURS_PER_MONTH", "730"))

GP3_BASE_IOPS = Decimal(3000)
GP3_BASE_THROUGHPUT_MIBPS = Decimal(125)
GP3_MAX_IOPS = Decimal(80000)
GP3_MAX_THROUGHPUT_MIBPS = Decimal(2000)
GP3_MAX_IOPS_PER_GIB = Decimal(500)
GP3_MAX_THROUGHPUT_PER_IOPS = Decimal("0.25")


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def money(x: Decimal, places: int = 6) -> str:
    q = Decimal(10) ** -places
    return f"${format(x.quantize(q), f'.{places}f')}"


def num(x: Decimal, places: int = 3) -> str:
    q = Decimal(10) ** -places
    return format(x.quantize(q), f'.{places}f')


def load_offer(service: str, region: str, refresh: bool) -> dict[str, Any]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{service}-{region}.json"
    if not path.exists() or refresh:
        url = f"{PRICE_ROOT}/{service}/current/{region}/index.json"
        print(f"fetching {url}", file=sys.stderr)
        tmp = path.with_suffix(".tmp")
        with urllib.request.urlopen(url, timeout=180) as response:
            tmp.write_bytes(response.read())
        tmp.replace(path)
    with path.open("rb") as f:
        return json.load(f)


def on_demand_dimensions(data: dict[str, Any], sku: str) -> list[dict[str, Any]]:
    dims: list[dict[str, Any]] = []
    for term in data.get("terms", {}).get("OnDemand", {}).get(sku, {}).values():
        dims.extend(term.get("priceDimensions", {}).values())
    return dims


def first_price_dimension(data: dict[str, Any], sku: str, unit: str | None = None) -> dict[str, Any]:
    dims = on_demand_dimensions(data, sku)
    if unit is not None:
        dims = [d for d in dims if d.get("unit") == unit]
    if not dims:
        die(f"no OnDemand price dimension found for SKU {sku}")
    return dims[0]


def price_from_dimension(dim: dict[str, Any]) -> Decimal:
    return Decimal(dim["pricePerUnit"]["USD"])


def find_ec2(data: dict[str, Any], instance_type: str) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []
    for sku, product in data.get("products", {}).items():
        attrs = product.get("attributes", {})
        if attrs.get("instanceType") != instance_type:
            continue
        if attrs.get("operatingSystem") != "Linux":
            continue
        if attrs.get("tenancy") != "Shared":
            continue
        if attrs.get("preInstalledSw") != "NA":
            continue
        if attrs.get("capacitystatus") != "Used":
            continue
        dim = first_price_dimension(data, sku, unit="Hrs")
        matches.append({"sku": sku, "product": product, "dimension": dim})
    if not matches:
        die(f"no Linux Shared On-Demand price found for {instance_type}")
    if len(matches) > 1:
        print(f"warning: {len(matches)} EC2 price matches for {instance_type}; using first", file=sys.stderr)
    return matches[0]


def ec2_price(data: dict[str, Any], instance_type: str) -> Decimal:
    return price_from_dimension(find_ec2(data, instance_type)["dimension"])


def describe_instance_types(region: str, instance_types: list[str]) -> dict[str, Any]:
    if not shutil.which("aws"):
        return {}
    cmd = [
        "aws",
        "ec2",
        "describe-instance-types",
        "--region",
        region,
        "--instance-types",
        *instance_types,
        "--output",
        "json",
    ]
    try:
        raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=60)
    except Exception:
        return {}
    data = json.loads(raw)
    return {item["InstanceType"]: item for item in data.get("InstanceTypes", [])}


def find_ebs_dimension(data: dict[str, Any], usagetype_suffix: str) -> dict[str, Any]:
    matches: list[tuple[str, dict[str, Any], dict[str, Any]]] = []
    for sku, product in data.get("products", {}).items():
        attrs = product.get("attributes", {})
        usagetype = attrs.get("usagetype", "")
        if usagetype.endswith(usagetype_suffix):
            dim = first_price_dimension(data, sku)
            matches.append((sku, product, dim))
    if not matches:
        die(f"no EBS price found for usagetype suffix {usagetype_suffix}")
    sku, product, dim = matches[0]
    return {"sku": sku, "product": product, "dimension": dim}


def gp3_prices(data: dict[str, Any]) -> dict[str, Decimal | str]:
    storage = find_ebs_dimension(data, "VolumeUsage.gp3")
    iops = find_ebs_dimension(data, "VolumeP-IOPS.gp3")
    throughput = find_ebs_dimension(data, "VolumeP-Throughput.gp3")

    storage_price = price_from_dimension(storage["dimension"])
    iops_price = price_from_dimension(iops["dimension"])
    throughput_price = price_from_dimension(throughput["dimension"])
    throughput_unit = throughput["dimension"].get("unit")
    if throughput_unit == "GiBps-mo":
        throughput_price = throughput_price / Decimal(1024)

    return {
        "storage_per_gb_month": storage_price,
        "storage_sku": storage["sku"],
        "storage_rate": storage["dimension"].get("rateCode", ""),
        "iops_per_iops_month": iops_price,
        "iops_sku": iops["sku"],
        "iops_rate": iops["dimension"].get("rateCode", ""),
        "throughput_per_mibps_month": throughput_price,
        "throughput_sku": throughput["sku"],
        "throughput_rate": throughput["dimension"].get("rateCode", ""),
    }


def gp3_cost(prices: dict[str, Decimal | str], size_gb: Decimal, iops: Decimal, throughput_mibps: Decimal) -> dict[str, Decimal]:
    storage_cost = size_gb * prices["storage_per_gb_month"]  # type: ignore[operator]
    paid_iops = max(Decimal(0), iops - GP3_BASE_IOPS)
    iops_cost = paid_iops * prices["iops_per_iops_month"]  # type: ignore[operator]
    paid_throughput = max(Decimal(0), throughput_mibps - GP3_BASE_THROUGHPUT_MIBPS)
    throughput_cost = paid_throughput * prices["throughput_per_mibps_month"]  # type: ignore[operator]
    monthly = storage_cost + iops_cost + throughput_cost
    return {
        "storage_monthly": storage_cost,
        "paid_iops": paid_iops,
        "iops_monthly": iops_cost,
        "paid_throughput_mibps": paid_throughput,
        "throughput_monthly": throughput_cost,
        "monthly": monthly,
        "hourly": monthly / HOURS_PER_MONTH,
    }


def gp3_warnings(size_gb: Decimal, iops: Decimal, throughput_mibps: Decimal, instance: dict[str, Any] | None = None) -> list[str]:
    warnings: list[str] = []
    if iops > GP3_MAX_IOPS:
        warnings.append(f"gp3 IOPS {iops} exceeds max {GP3_MAX_IOPS}")
    if throughput_mibps > GP3_MAX_THROUGHPUT_MIBPS:
        warnings.append(f"gp3 throughput {throughput_mibps} MiB/s exceeds max {GP3_MAX_THROUGHPUT_MIBPS}")
    if iops > size_gb * GP3_MAX_IOPS_PER_GIB:
        warnings.append(f"gp3 IOPS {iops} exceeds density {GP3_MAX_IOPS_PER_GIB} IOPS/GiB for {size_gb} GB")
    required_iops = throughput_mibps / GP3_MAX_THROUGHPUT_PER_IOPS
    if iops < required_iops:
        warnings.append(f"gp3 throughput {throughput_mibps} MiB/s requires at least {required_iops} IOPS")
    if instance:
        ebs = instance.get("EbsInfo", {}).get("EbsOptimizedInfo", {})
        max_iops = ebs.get("MaximumIops") or ebs.get("BaselineIops")
        max_mbps = ebs.get("MaximumThroughputInMBps") or ebs.get("BaselineThroughputInMBps")
        if max_iops and iops > Decimal(str(max_iops)):
            warnings.append(f"instance EBS IOPS cap {max_iops} is below requested {iops}")
        if max_mbps and throughput_mibps > Decimal(str(max_mbps)):
            warnings.append(f"instance EBS throughput cap {max_mbps} MB/s is below requested {throughput_mibps} MiB/s")
    return warnings


def cmd_ec2(args: argparse.Namespace) -> None:
    data = load_offer("AmazonEC2", args.region, args.refresh)
    specs = describe_instance_types(args.region, args.instance_types)
    for it in args.instance_types:
        match = find_ec2(data, it)
        dim = match["dimension"]
        attrs = match["product"].get("attributes", {})
        price = price_from_dimension(dim)
        print(f"{it}: {money(price, 5)}/hr")
        print(f"  sku: {match['sku']}")
        print(f"  rate: {dim.get('rateCode', '')}")
        print(f"  desc: {dim.get('description', '')}")
        print(f"  attrs: vCPU={attrs.get('vcpu')} memory={attrs.get('memory')} storage={attrs.get('storage')} network={attrs.get('networkPerformance')}")
        spec = specs.get(it)
        if spec:
            storage = spec.get("InstanceStorageInfo")
            ebs = spec.get("EbsInfo", {}).get("EbsOptimizedInfo", {})
            print(f"  ec2-api storage: {json.dumps(storage, sort_keys=True)}")
            print(f"  ec2-api ebs: {json.dumps(ebs, sort_keys=True)}")
        print()


def cmd_gp3(args: argparse.Namespace) -> None:
    data = load_offer("AmazonEC2", args.region, args.refresh)
    prices = gp3_prices(data)
    size = Decimal(str(args.size_gb))
    iops = Decimal(str(args.iops))
    throughput = Decimal(str(args.throughput_mibps))
    cost = gp3_cost(prices, size, iops, throughput)
    print(f"gp3 {args.region}: {num(size, 0)} GB, {num(iops, 0)} IOPS, {num(throughput, 0)} MiB/s")
    print(f"  storage:    {money(cost['storage_monthly'], 4)}/mo")
    print(f"  extra IOPS: {num(cost['paid_iops'], 0)} * {money(prices['iops_per_iops_month'], 6)} = {money(cost['iops_monthly'], 4)}/mo")
    print(f"  extra thr:  {num(cost['paid_throughput_mibps'], 0)} MiB/s * {money(prices['throughput_per_mibps_month'], 6)} = {money(cost['throughput_monthly'], 4)}/mo")
    print(f"  total:      {money(cost['monthly'], 4)}/mo = {money(cost['hourly'], 6)}/hr")
    print("  sources:")
    print(f"    storage SKU/rate:    {prices['storage_sku']} / {prices['storage_rate']}")
    print(f"    IOPS SKU/rate:       {prices['iops_sku']} / {prices['iops_rate']}")
    print(f"    throughput SKU/rate: {prices['throughput_sku']} / {prices['throughput_rate']}")
    for warning in gp3_warnings(size, iops, throughput):
        print(f"  warning: {warning}")


def find_s3_standard_get(data: dict[str, Any]) -> dict[str, Any]:
    matches: list[tuple[str, dict[str, Any], dict[str, Any]]] = []
    for sku, product in data.get("products", {}).items():
        attrs = product.get("attributes", {})
        if attrs.get("group") != "S3-API-Tier2":
            continue
        if attrs.get("groupDescription") != "GET and all other requests":
            continue
        dim = first_price_dimension(data, sku, unit="Requests")
        matches.append((sku, product, dim))
    if not matches:
        die("no S3 Standard GET/all-other request price found")
    sku, product, dim = matches[0]
    return {"sku": sku, "product": product, "dimension": dim}


def cmd_s3_get(args: argparse.Namespace) -> None:
    data = load_offer("AmazonS3", args.region, args.refresh)
    match = find_s3_standard_get(data)
    dim = match["dimension"]
    price_per_request = price_from_dimension(dim)
    requests = Decimal(str(args.requests)) if args.requests is not None else None
    print(f"S3 Standard GET/all-other requests {args.region}: {money(price_per_request, 10)}/request")
    print(f"  per 10k requests: {money(price_per_request * Decimal(10000), 6)}")
    print(f"  sku: {match['sku']}")
    print(f"  rate: {dim.get('rateCode', '')}")
    print(f"  desc: {dim.get('description', '')}")
    if requests is not None:
        print(f"  {num(requests, 0)} requests cost: {money(price_per_request * requests, 6)}")


def cmd_parity(args: argparse.Namespace) -> None:
    data = load_offer("AmazonEC2", args.region, args.refresh)
    prices = gp3_prices(data)
    local_price = ec2_price(data, args.with_local)
    ebs_only_price = ec2_price(data, args.ebs_only)
    if local_price <= ebs_only_price:
        die(f"{args.with_local} is not more expensive than {args.ebs_only}; no EBS budget")

    size = Decimal(str(args.size_gb))
    throughput = Decimal(str(args.throughput_mibps))
    budget_hourly = local_price - ebs_only_price
    budget_monthly = budget_hourly * HOURS_PER_MONTH

    fixed = gp3_cost(prices, size, GP3_BASE_IOPS, throughput)
    remaining = budget_monthly - fixed["monthly"]
    iops = GP3_BASE_IOPS + remaining / prices["iops_per_iops_month"]  # type: ignore[operator]
    if remaining < 0:
        iops = GP3_BASE_IOPS
    final = gp3_cost(prices, size, iops, throughput)
    combined = ebs_only_price + final["hourly"]

    specs = describe_instance_types(args.region, [args.with_local, args.ebs_only])
    print(f"region: {args.region}")
    print(f"{args.with_local}: {money(local_price, 5)}/hr")
    print(f"{args.ebs_only}: {money(ebs_only_price, 5)}/hr")
    print(f"EBS parity budget: {money(budget_hourly, 5)}/hr = {money(budget_monthly, 4)}/mo")
    print()
    print(f"Fixed EBS: {num(size, 0)} GB gp3, {num(throughput, 0)} MiB/s")
    print(f"Parity IOPS: {num(iops, 0)}")
    print(f"  storage:    {money(final['storage_monthly'], 4)}/mo")
    print(f"  throughput: {money(final['throughput_monthly'], 4)}/mo")
    print(f"  IOPS:       {money(final['iops_monthly'], 4)}/mo")
    print(f"  EBS total:  {money(final['monthly'], 4)}/mo = {money(final['hourly'], 6)}/hr")
    print(f"  combined:   {money(combined, 6)}/hr")
    print()
    local_spec = specs.get(args.with_local)
    ebs_spec = specs.get(args.ebs_only)
    if local_spec:
        print(f"{args.with_local} local storage: {json.dumps(local_spec.get('InstanceStorageInfo'), sort_keys=True)}")
    if ebs_spec:
        print(f"{args.ebs_only} EBS caps: {json.dumps(ebs_spec.get('EbsInfo', {}).get('EbsOptimizedInfo', {}), sort_keys=True)}")
    for warning in gp3_warnings(size, iops, throughput, ebs_spec):
        print(f"warning: {warning}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Official AWS EC2/EBS gp3 pricing helper")
    parser.add_argument("--refresh", action="store_true", help="refetch AWS bulk price file instead of using cache")
    sub = parser.add_subparsers(dest="command", required=True)

    ec2 = sub.add_parser("ec2", help="show Linux Shared On-Demand EC2 prices and specs")
    ec2.add_argument("--region", required=True)
    ec2.add_argument("instance_types", nargs="+")
    ec2.set_defaults(func=cmd_ec2)

    gp3 = sub.add_parser("gp3", help="calculate gp3 volume cost")
    gp3.add_argument("--region", required=True)
    gp3.add_argument("--size-gb", required=True, type=Decimal)
    gp3.add_argument("--iops", required=True, type=Decimal)
    gp3.add_argument("--throughput-mibps", required=True, type=Decimal)
    gp3.set_defaults(func=cmd_gp3)

    s3 = sub.add_parser("s3-get", help="show S3 Standard GET/all-other request price")
    s3.add_argument("--region", required=True)
    s3.add_argument("--requests", type=Decimal, help="optional request count to price")
    s3.set_defaults(func=cmd_s3_get)

    parity = sub.add_parser("parity", help="price-match local-NVMe instance against EBS-only instance + gp3")
    parity.add_argument("--region", required=True)
    parity.add_argument("--with-local", required=True, help="instance with local NVMe, e.g. m8gd.24xlarge")
    parity.add_argument("--ebs-only", required=True, help="EBS-only sibling, e.g. m8g.24xlarge")
    parity.add_argument("--size-gb", required=True, type=Decimal, help="fixed gp3 volume size")
    parity.add_argument("--throughput-mibps", required=True, type=Decimal, help="fixed gp3 throughput")
    parity.set_defaults(func=cmd_parity)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
