#!/usr/bin/env python3
"""WORKED EXAMPLE (frozen copy, 2026-07-15) — slides in a live shared deck.

Demonstrates every pattern from SKILL.md's shared-deck recipe: objectId
anchoring, createSlide + placeholderIdMappings, idempotent prefixed ids,
styled metric boxes (FIXED_RANGE), Drive-URL images, two-phase speaker notes,
deleteText-on-empty guard. Deck/layout/image IDs are specific to that deck;
adapt them, don't run this as-is.

Original task: Miguel's Smart Query Routing slides in the shared AH deck, in place.

Creates REAL editable slides (deck's own 'Basic Light' layout + placeholders),
anchored at runtime on the section slide objectId so peer edits can't move us.
Idempotent: deletes previously created smr_* slides/elements before re-creating.
Also sets speaker notes (phase 2, after slide creation).

Run:
  source ~/.gog_secret
  uv run --quiet --with jwcrypto,requests python build_ah_slides.py [--dry-run]

Storyboard (2026-07-15 review): recap -> costs -> margin -> users -> joke -> ask.
NOTE: smr_next numbers must be refreshed on Jul 16 AM with v8 prod data (v8
deployed Jul 15 morning).
"""

import json
import subprocess
import sys

DECK = "1_Mbz5gBHfrs4s1dvgPBPr9Damk_sd8ulBLV6wkgEbIc"
GSLIDES = ["uv", "run", "--quiet", "--with", "jwcrypto,requests", "python",
           "/home/miguel/.pi/agent/skills/google-slides/scripts/gslides.py"]

SECTION_ID = "g3f51e30ea13_1_11"   # "Smart Query Routing / Miguel"
CONTENT1_ID = "g3f51e30ea13_1_6"   # reserved slide, becomes the recap
CONTENT1_TITLE = "g3f51e30ea13_1_7"
CONTENT1_BODY = "g3f51e30ea13_1_8"
LAYOUT_BASIC_LIGHT = "g3637e2c189c_0_19598"
MEME_IMAGE_URL = "https://drive.google.com/uc?export=download&id=1ztC6TSA5Do669IR30eytybCOgCpQeucw"
MEME_ASPECT = 388 / 318  # w/h of obama-medal-clean.png
CHART_14D_URL = "https://drive.google.com/uc?export=download&id=1R4fa0x2QMO2i6TnFejQ0nTrZk9733wDi"
CHART_14D_ASPECT = 1124 / 347  # routed_share_14d.png
CHART_V8_URL = "https://drive.google.com/uc?export=download&id=1IDdvXwygbOXezZaTPRQnLzsRQ-HsFydW"
CHART_V8_ASPECT = 1104 / 347  # v8_deploy_today.png
PRIOR_AH = "https://docs.google.com/presentation/d/1eQVsSu8Qh_ygK8TJ_HmtYWup_L-zGZv5XoRdKUqZ3Ys/edit (slides 5-8)"

# layout placeholder geometry (base size 3000000 EMU square, scaled)
TITLE_TRANSFORM = {"scaleX": 2.9, "scaleY": 0.1709,
                   "translateX": 240050, "translateY": 727125, "unit": "EMU"}
BODY_TRANSFORM = {"scaleX": 2.9, "scaleY": 1.1852,
                  "translateX": 240050, "translateY": 1359364, "unit": "EMU"}
FOOTER_TRANSFORM = {"scaleX": 3.0, "scaleY": 0.25,
                    "translateX": 240050, "translateY": int(4.7 * 914400), "unit": "EMU"}

EMU = 914400  # per inch

ORANGE = {"red": 0xD3 / 255, "green": 0x4E / 255, "blue": 0x2D / 255}
OFFBLACK = {"red": 0x17 / 255, "green": 0x17 / 255, "blue": 0x17 / 255}
GRAY = {"red": 0x99 / 255, "green": 0x99 / 255, "blue": 0x9B / 255}

NOTES = {
    CONTENT1_ID: (
        "Recap of the prior all-hands pitch: " + PRIOR_AH + ". "
        "571k executions in the first 13 days. Misroutes abort and fall back in ~12s, "
        "so routing can be aggressive. Live at 100% since Jun 30. "
        "One $142/day node is saving us $1,300/day."
    ),
    "smr_costs": (
        "Windows: Jun 1-13 vs Jul 1-13. Captures the full SMR package incl. autoscaling "
        "tuning. July demand was seasonally lighter, so per-unit numbers (next slide) "
        "confirm the gain, not just raw spend."
    ),
    "smr_margin": (
        "Do NOT add the -21.5% and +13%: margin is the quotient of revenue and cost "
        "moves. If asked: credits fell 7%, cost fell 18%, ratio is +13%. "
        "The >120s bucket doubles as a control group: it validates the measurement. "
        "Full method and caveats: DF-726."
    ),
    "smr_users": (
        "Revenue windows: Jun 9-21 vs Jul 1-13 (excludes the Jun 9 pricing change). "
        "Routed queries: median 0.8s, p90 3x faster, billed elapsed ~5x lower; "
        "customers charged -7% credits overall. "
        "Same-lane prices unchanged: short queries on big clusters still bill the same."
    ),
    "smr_meme": "Yes, this slide is the reward. The next one is the ask.",
    "smr_next": (
        "REFRESH NUMBERS TOMORROW MORNING (Jul 16): v8 deployed Jul 15 AM, exact "
        "routed-share to be recalculated from prod data (chart avg 48% fast execution "
        "since deploy; ~38% effective offload target). "
        "Each extra 7pp of routed share was worth ~$127k/yr at v6 economics. "
        "Escape hatches: instant flag back to v6, ramp ratio, size-map dial."
    ),
}


def gslides(*args: str, stdin: str | None = None) -> dict:
    out = subprocess.run(GSLIDES + list(args), capture_output=True, text=True, input=stdin)
    if out.returncode != 0:
        sys.exit(f"gslides {args[0]} failed: {out.stderr or out.stdout}")
    return json.loads(out.stdout)


def color(rgb: dict) -> dict:
    return {"opaqueColor": {"rgbColor": rgb}}


def textbox(oid: str, slide: str, x: float, y: float, w: float, h: float) -> dict:
    return {"createShape": {
        "objectId": oid,
        "shapeType": "TEXT_BOX",
        "elementProperties": {
            "pageObjectId": slide,
            "size": {"width": {"magnitude": int(w * EMU), "unit": "EMU"},
                     "height": {"magnitude": int(h * EMU), "unit": "EMU"}},
            "transform": {"scaleX": 1, "scaleY": 1,
                          "translateX": int(x * EMU), "translateY": int(y * EMU),
                          "unit": "EMU"},
        },
    }}


def metric_box(oid: str, slide: str, x: float, y: float, w: float,
               number: str, label: str, detail: str = "") -> list[dict]:
    """Big number (Geist bold, orange) + small caps label (gray) + optional detail."""
    text = number + "\n" + label + ("\n" + detail if detail else "")
    n_end = len(number)
    l_end = n_end + 1 + len(label)
    reqs = [
        textbox(oid, slide, x, y, w, 1.6),
        {"insertText": {"objectId": oid, "text": text}},
        {"updateTextStyle": {
            "objectId": oid,
            "textRange": {"type": "FIXED_RANGE", "startIndex": 0, "endIndex": n_end},
            "style": {"fontFamily": "Geist", "bold": True,
                      "fontSize": {"magnitude": 34, "unit": "PT"},
                      "foregroundColor": color(ORANGE)},
            "fields": "fontFamily,bold,fontSize,foregroundColor",
        }},
        {"updateTextStyle": {
            "objectId": oid,
            "textRange": {"type": "FIXED_RANGE", "startIndex": n_end + 1, "endIndex": l_end},
            "style": {"fontFamily": "Geist", "bold": False,
                      "fontSize": {"magnitude": 10, "unit": "PT"},
                      "foregroundColor": color(GRAY)},
            "fields": "fontFamily,bold,fontSize,foregroundColor",
        }},
    ]
    if detail:
        reqs.append({"updateTextStyle": {
            "objectId": oid,
            "textRange": {"type": "FIXED_RANGE", "startIndex": l_end + 1, "endIndex": len(text)},
            "style": {"fontFamily": "Geist",
                      "fontSize": {"magnitude": 11, "unit": "PT"},
                      "foregroundColor": color(OFFBLACK)},
            "fields": "fontFamily,fontSize,foregroundColor",
        }})
    return reqs


def widen(oid: str, transform: dict) -> dict:
    return {"updatePageElementTransform": {
        "objectId": oid, "applyMode": "ABSOLUTE", "transform": transform}}


def bullets(oid: str) -> dict:
    return {"createParagraphBullets": {
        "objectId": oid, "textRange": {"type": "ALL"},
        "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"}}


def image(oid: str, slide: str, url: str, x: float, y: float,
          w: float, aspect: float) -> dict:
    h = w / aspect
    return {"createImage": {
        "objectId": oid,
        "url": url,
        "elementProperties": {
            "pageObjectId": slide,
            "size": {"width": {"magnitude": int(w * EMU), "unit": "EMU"},
                     "height": {"magnitude": int(h * EMU), "unit": "EMU"}},
            "transform": {"scaleX": 1, "scaleY": 1,
                          "translateX": int(x * EMU), "translateY": int(y * EMU),
                          "unit": "EMU"},
        },
    }}


def new_slide(oid: str, index: int) -> dict:
    return {"createSlide": {
        "objectId": oid,
        "insertionIndex": index,
        "slideLayoutReference": {"layoutId": LAYOUT_BASIC_LIGHT},
        "placeholderIdMappings": [
            {"layoutPlaceholder": {"type": "TITLE", "index": 0}, "objectId": f"{oid}_title"},
            {"layoutPlaceholder": {"type": "SUBTITLE", "index": 0}, "objectId": f"{oid}_body"},
        ],
    }}


def content_slide(oid: str, index: int, title: str, body: str,
                  body_transform: dict | None = BODY_TRANSFORM,
                  with_bullets: bool = True) -> list[dict]:
    reqs = [
        new_slide(oid, index),
        {"insertText": {"objectId": f"{oid}_title", "text": title}},
        widen(f"{oid}_title", TITLE_TRANSFORM),
    ]
    if body:
        reqs.append({"insertText": {"objectId": f"{oid}_body", "text": body}})
        if body_transform:
            reqs.append(widen(f"{oid}_body", body_transform))
        if with_bullets:
            reqs.append(bullets(f"{oid}_body"))
    else:
        reqs.append({"deleteObject": {"objectId": f"{oid}_body"}})
    return reqs


def build_requests() -> list[dict]:
    deck = gslides("get", DECK,
                   "slides(objectId,pageElements(objectId,shape.text.textElements))")
    ids = [s["objectId"] for s in deck["slides"]]
    if SECTION_ID not in ids or CONTENT1_ID not in ids:
        sys.exit(f"anchor slides missing; deck order: {ids}")
    has_text = {
        e["objectId"]
        for s in deck["slides"] for e in s.get("pageElements", [])
        if any("textRun" in te
               for te in e.get("shape", {}).get("text", {}).get("textElements", []))
    }

    reqs: list[dict] = []

    # idempotency: drop previous smr_* slides and smr_* elements on kept slides
    for s in deck["slides"]:
        sid = s["objectId"]
        if sid.startswith("smr_"):
            reqs.append({"deleteObject": {"objectId": sid}})
            continue
        for e in s.get("pageElements", []):
            if e["objectId"].startswith("smr_"):
                reqs.append({"deleteObject": {"objectId": e["objectId"]}})
    ids = [i for i in ids if not i.startswith("smr_")]
    base = ids.index(CONTENT1_ID) + 1

    # --- slide 0: recap (existing reserved slide) ---
    for oid in (CONTENT1_TITLE, CONTENT1_BODY):
        if oid in has_text:
            reqs.append({"deleteText": {"objectId": oid, "textRange": {"type": "ALL"}}})
    reqs += [
        {"insertText": {"objectId": CONTENT1_TITLE,
                        "text": "Recap: offload the cheap majority to one cheap node"}},
        {"insertText": {"objectId": CONTENT1_BODY, "text": (
            "The plan (last all-hands): classify at submit time, send the cheap "
            "~40% to a single-node fast lane. Expensive clusters keep the heavy work.\n"
            "In production, at 100% of traffic, since Jun 30."
        )}},
        widen(CONTENT1_TITLE, TITLE_TRANSFORM),
        widen(CONTENT1_BODY, BODY_TRANSFORM),
        bullets(CONTENT1_BODY),
    ]
    reqs += metric_box("smr_m0a", CONTENT1_ID, 0.4, 3.5, 2.3,
                       "28%", "ROUTED TO THE FAST LANE, IN PROD")
    reqs.append(image("smr_c0", CONTENT1_ID, CHART_14D_URL,
                      2.9, 2.85, 6.8, CHART_14D_ASPECT))

    # --- slide 1: costs ---
    reqs += content_slide(
        "smr_costs", base,
        "Costs: the DuneSQL fleet is a fifth cheaper",
        "Measured on the first 13 days at 100%: infra spend across all DuneSQL "
        "clusters, all-in.",
    )
    reqs += metric_box("smr_m1a", "smr_costs", 0.5, 3.0, 4.0,
                       "-21.5%", "DUNESQL INFRA SPEND",
                       "Jun 1-13 vs Jul 1-13, full package.")
    reqs += metric_box("smr_m1b", "smr_costs", 5.2, 3.0, 4.0,
                       "-$484k/yr", "RUN-RATE, 1-YEAR PROJECTION",
                       "At current traffic and prices.")

    # --- slide 2: margin / unit economics ---
    reqs += content_slide(
        "smr_margin", base + 1,
        "Margin: more credits per infra dollar",
        "Heavy queries (>120s) untouched: credits +0.0%. "
        "The control group that validates the measurement.",
        body_transform=FOOTER_TRANSFORM, with_bullets=False,
    )
    reqs += metric_box("smr_m2a", "smr_margin", 0.4, 2.0, 6.0,
                       "+13%", "CREDITS CHARGED PER INFRA-$ SPENT, FLEET-WIDE",
                       "Returned a third of the savings to customers as speed, kept the rest.")

    # --- slide 3: users ---
    reqs += content_slide(
        "smr_users", base + 2,
        "Users: faster answers, charged less",
        "Fast, light queries get answers faster and bill less. "
        "Prices on the big clusters are unchanged.",
    )
    reqs += metric_box("smr_m3a", "smr_users", 0.5, 3.0, 4.0,
                       "5x", "FASTER, FAST/LIGHT QUERIES")
    reqs += metric_box("smr_m3b", "smr_users", 5.2, 3.0, 4.0,
                       "3x", "CHEAPER, FAST/LIGHT QUERIES",
                       "On average 7% customer savings.")

    # --- slide 4: the joke ---
    img_h = 3.6
    img_w = img_h * MEME_ASPECT
    reqs += content_slide("smr_meme", base + 3,
                          "Cut costs. Raised margins. Made it faster.", "")
    reqs.append({"createImage": {
        "objectId": "smr_meme_img",
        "url": MEME_IMAGE_URL,
        "elementProperties": {
            "pageObjectId": "smr_meme",
            "size": {"width": {"magnitude": int(img_w * EMU), "unit": "EMU"},
                     "height": {"magnitude": int(img_h * EMU), "unit": "EMU"}},
            "transform": {"scaleX": 1, "scaleY": 1,
                          "translateX": int((10 - img_w) / 2 * EMU),
                          "translateY": int(1.55 * EMU), "unit": "EMU"},
        },
    }})

    # --- slide 5: the ask (numbers refresh Jul 16 AM from v8 prod data) ---
    reqs += content_slide(
        "smr_next", base + 4,
        "The fast lane is not full. The classifier is the dial.",
        "Raising the routed share compounds the savings and the unit economics, "
        "at zero extra infra.\n"
        "New classifier (v8) deployed this morning: averaging 48% fast execution since.",
    )
    reqs += metric_box("smr_m4a", "smr_next", 0.4, 3.5, 2.3,
                       "28% \u2192 ~38%", "ROUTED SHARE TARGET")
    reqs.append(image("smr_c4", "smr_next", CHART_V8_URL,
                      2.9, 2.9, 6.8, CHART_V8_ASPECT))

    return reqs


def notes_requests() -> list[dict]:
    deck = gslides(
        "get", DECK,
        "slides(objectId,slideProperties.notesPage.pageElements"
        "(objectId,shape(placeholder,text.textElements)))")
    reqs: list[dict] = []
    for s in deck["slides"]:
        if s["objectId"] not in NOTES:
            continue
        for e in s["slideProperties"]["notesPage"].get("pageElements", []):
            ph = e.get("shape", {}).get("placeholder", {})
            if ph.get("type") != "BODY":
                continue
            if any("textRun" in te for te in
                   e.get("shape", {}).get("text", {}).get("textElements", [])):
                reqs.append({"deleteText": {"objectId": e["objectId"],
                                            "textRange": {"type": "ALL"}}})
            reqs.append({"insertText": {"objectId": e["objectId"],
                                        "text": NOTES[s["objectId"]]}})
    return reqs


def main() -> None:
    dry = "--dry-run" in sys.argv
    reqs = build_requests()
    if dry:
        print(json.dumps(reqs, indent=1))
        return
    gslides("batch", DECK, "-", stdin=json.dumps(reqs))
    print("slides:", len(reqs), "requests applied")
    nreqs = notes_requests()
    gslides("batch", DECK, "-", stdin=json.dumps(nreqs))
    print("notes:", len(nreqs), "requests applied")


if __name__ == "__main__":
    main()
