#!/usr/bin/env python3
"""Direct Google Slides API access using gog's stored OAuth credentials.

gog (v0.14) has no batchUpdate, so it cannot create editable text slides at a
position, style runs, or place images freely. This helper unlocks the full
Slides REST API by minting an access token from gog's file-backend keyring.

Requires: GOG_KEYRING_PASSWORD in env (source ~/.gog_secret). Never prints secrets.

Usage:
  uv run --quiet --with jwcrypto,requests python gslides.py get <presentationId> [fields]
  uv run --quiet --with jwcrypto,requests python gslides.py batch <presentationId> <requests.json|->
  uv run --quiet --with jwcrypto,requests python gslides.py thumbnail <presentationId> <pageId> <out.png>

`batch` accepts a JSON file (or stdin with -) containing either a list of
request objects or {"requests": [...]}. Prints the batchUpdate reply JSON.
"""

import base64
import glob
import json
import os
import sys

import requests
from jwcrypto import jwe, jwk

KEYRING_GLOB = "~/.config/gogcli/keyring/_gogcli_key_v1_*"
CREDS_PATH = "~/.config/gogcli/credentials.json"
SLIDES = "https://slides.googleapis.com/v1/presentations"


def access_token(account: str | None = None) -> str:
    pw = os.environ.get("GOG_KEYRING_PASSWORD")
    if not pw:
        sys.exit("GOG_KEYRING_PASSWORD not set (source ~/.gog_secret)")
    key = jwk.JWK.from_password(pw)
    refresh = None
    for f in sorted(glob.glob(os.path.expanduser(KEYRING_GLOB))):
        token = jwe.JWE()
        try:
            token.deserialize(open(f).read(), key=key)
        except Exception:
            continue
        payload = json.loads(token.payload)
        data = json.loads(base64.b64decode(payload["Data"]))
        if "refresh_token" not in data:
            continue
        if account and data.get("email") != account:
            continue
        refresh = data["refresh_token"]
        break
    if not refresh:
        sys.exit("no refresh token found in gog keyring")
    creds = json.load(open(os.path.expanduser(CREDS_PATH)))
    r = requests.post(
        "https://oauth2.googleapis.com/token",
        data={
            "client_id": creds["client_id"],
            "client_secret": creds["client_secret"],
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        },
        timeout=30,
    )
    r.raise_for_status()
    return r.json()["access_token"]


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, pres = sys.argv[1], sys.argv[2]
    hdr = {"Authorization": f"Bearer {access_token(os.environ.get('GSLIDES_ACCOUNT'))}"}

    if cmd == "get":
        params = {"fields": sys.argv[3]} if len(sys.argv) > 3 else {}
        r = requests.get(f"{SLIDES}/{pres}", headers=hdr, params=params, timeout=60)
    elif cmd == "batch":
        src = sys.stdin.read() if sys.argv[3] == "-" else open(sys.argv[3]).read()
        body = json.loads(src)
        if isinstance(body, list):
            body = {"requests": body}
        r = requests.post(f"{SLIDES}/{pres}:batchUpdate", headers=hdr, json=body, timeout=60)
    elif cmd == "thumbnail":
        page, out = sys.argv[3], sys.argv[4]
        r = requests.get(
            f"{SLIDES}/{pres}/pages/{page}/thumbnail",
            headers=hdr,
            params={"thumbnailProperties.thumbnailSize": "LARGE"},
            timeout=60,
        )
        r.raise_for_status()
        img = requests.get(r.json()["contentUrl"], timeout=60)
        open(out, "wb").write(img.content)
        print(f"wrote {out} ({len(img.content)} bytes)")
        return
    else:
        sys.exit(f"unknown command {cmd}")

    if not r.ok:
        sys.exit(f"HTTP {r.status_code}: {r.text[:2000]}")
    print(json.dumps(r.json(), indent=1))


if __name__ == "__main__":
    main()
