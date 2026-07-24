---
name: google-slides
description: Build and edit on-brand Dune Google Slides decks programmatically via gog (Slides API) + python-pptx, with Geist fonts and the Dune brand palette. Use whenever the user wants to create, update, restyle, or read comments on a Google Slides presentation for Dune, or convert charts/diagrams into a deck. Covers brand extraction, chart/diagram rendering, the pptx->Slides build path, gog's edit limits, and self-verification via thumbnails.
---

# Google Slides (Dune-branded, programmatic)

Make Dune-styled decks reproducibly. Two build paths:
- **New deck**: matplotlib/graphviz assets -> python-pptx -> `gog drive upload --convert-to slides`.
- **Existing/shared deck (incl. live-edited by peers)**: direct Slides API `batchUpdate` via `scripts/gslides.py` — real editable text slides, in place, at any position.

Self-verify every slide with thumbnails. Source of truth is the build script, not the live deck.

## Auth (do this first)

`gog` wraps Drive + Slides APIs. Needed once:
- **Enable the Slides API** on the OAuth project: https://console.developers.google.com/apis/api/slides.googleapis.com/overview
- **Re-auth with the slides scope, keeping existing ones** (omitted services get revoked):
  `gog auth add <email> --services calendar,docs,drive,gmail,sheets,slides` (no `--readonly` for writes)
- Non-interactive shells (agents) need `GOG_KEYRING_PASSWORD`. Source it from the user's secret file, never print it:
  `source ~/.gog_secret 2>/dev/null` then `gog --account <email> ...`
- Smoke test: `gog --account <email> slides list-slides <id>`

## Brand system (extract from the style guide, don't guess)

The Dune style-guide deck carries the palette on a "Colour" slide and fonts in the theme.
- Export/download the pptx, then `unzip` it and read `ppt/theme/theme*.xml` for `clrScheme` + `fontScheme`. The **active** theme is the one the slideMaster references (`ppt/slideMasters/_rels/*.rels`).
- Or read the palette slide text directly (`gog slides read-slide`).

**Dune palette (theme3 / style-guide slide 25):**
| role | hex |
|---|---|
| Off-Black (text) | `#171717` |
| Deep-Gray / Gray / Light-Gray | `#2A2A2B` / `#99999B` / `#F7F7F7` |
| **Orange** (primary accent) | `#D34E2D` |
| Navy | `#0B2277` |
| Green | `#479A6F` |
| Blue | `#4D6AC7` |
| Pink | `#D4537D` |
| Yellow | `#F4DD71` |
| Mauve | `#A36CBD` |

Each accent has Light/Dark tints (e.g. Orange-Light `#FDF6E8`, Navy-Light `#E9F2FE`, Green-Light `#F6FFED`, Blue-Light `#ECF0FE`).

**Fonts:** primary **Geist**; mono **Geist Mono** / Roboto Mono. Install Geist locally (OFL, free) so matplotlib + graphviz render it:
```bash
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fsSL "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf" -o Geist.ttf
curl -fsSL "https://github.com/google/fonts/raw/main/ofl/geistmono/GeistMono%5Bwght%5D.ttf" -o GeistMono.ttf
fc-cache -f ~/.local/share/fonts
```
The user's Google workspace already has Geist, so pptx text in Geist renders correctly after conversion.

**Layout rule (style-guide slide 30):** screens are floor-to-ceiling; put key content **top-left** so the back row sees it. Title top-left, one-line takeaway under it (in Orange), chart/body below.

## Charts & diagrams

- **Charts:** matplotlib with a shared `dune_style.py` (registers Geist, sets palette, white bg, no top/right spines). Use Geist Mono for big numbers. **Save the exact plotted values to a CSV next to each chart** so re-render never re-queries. One render script per chart.
- **Diagrams:** graphviz `dot` with `fontname="Geist"` + brand hex fills/borders. Control aspect with `rankdir` (TB taller, LR wider) and `nodesep`/`ranksep`. Bigger boxes => wider; raise `nodesep` to restore height. Keep **few words per box** and big fonts (reviewers reject dense/skinny diagrams).
- **No em-dashes in any rendered text** — "X — blah" is an LLM tell. Use commas, colons, periods. (En-dashes in numeric/date ranges like `Mar–May` are fine.)

## Build path: pptx -> native editable Slides

`gog` cannot create styled text boxes from scratch. Build the deck as a **brand `.pptx` with python-pptx** (editable text boxes + embedded chart PNGs), then convert:
```bash
gog --account <email> drive upload deck.pptx --convert-to slides   # creates a NEW native, editable Slides file
```
- python-pptx: 16:9 = `Inches(13.333) x Inches(7.5)`; blank layout (`slide_layouts[6]`); add a white bg rect first; set `run.font.name="Geist"`, sizes in `Pt`, colors via `RGBColor`. Speaker notes via `slide.notes_slide.notes_text_frame`.
- Fit an image into a content box by reading its pixel size (PIL) and scaling to the box while preserving aspect.
- **Self-verify**: `gog slides list-slides <id>` then `gog slides thumbnail <id> p<N> --out /tmp/x.png` (size `large` = 1600x900) and read the PNG.

## Full Slides API access: `scripts/gslides.py` (batchUpdate unlocked)

gog (v0.14) has no `batchUpdate`, but its keyring is a local file backend (JWE, `GOG_KEYRING_PASSWORD`). `scripts/gslides.py` decrypts the refresh token, mints an access token, and exposes the raw REST API — full editing power on any deck, same link, real editable text:

```bash
source ~/.gog_secret
G="uv run --quiet --with jwcrypto,requests python <skilldir>/scripts/gslides.py"
$G get   <deckId> [fieldMask]          # presentation JSON (layouts, elements, transforms)
$G batch <deckId> <requests.json|->    # any batchUpdate requests
$G thumbnail <deckId> <pageId> <out.png>
```

**Editing a live shared deck (peers editing concurrently — slide numbers move):**
- **Anchor by objectId, never by slide number.** Fetch `slides.objectId`, locate your section slide, compute `insertionIndex` at runtime. Positions drift **mid-session** (peers insert/delete while you work): re-fetch before every batch, and when talking to the user identify slides by title, not number.
- Standard Slides page = **10 x 5.625 in = 9144000 x 5143500 EMU** (not pptx's 13.333x7.5). Verify with `get <deck> pageSize` before placing elements.
- **Create slides with the deck's own layout** + `placeholderIdMappings` (TITLE/SUBTITLE): text inherits the house theme, stays editable, and gets logo/page-number from the master. Match how peers' slides are built (inspect their slides via `get`).
- **Prefix your objectIds** (e.g. `smr_win`, `smr_m2a`) and make the build script idempotent: delete `smr_*` slides/elements first, then re-create. Script per deck = source of truth; safe to re-run after every tweak.
- Slide deletion in batchUpdate is `deleteObject` (there is no `deleteSlide` request type).
- Layout placeholders are often narrow (title ~4.8in): widen with `updatePageElementTransform` (ABSOLUTE; base size commonly 3000000 EMU square, scaled). 1in = 914400 EMU.
- `createImage` needs a **fetchable URL**: upload to Drive (`gog drive upload`), `gog drive share <id> --to anyone --role reader`, use `https://drive.google.com/uc?export=download&id=<id>`. The image bytes are **copied** into the deck — revoke/delete the Drive file after.
- **`deleteText {type: ALL}` on an empty shape is a 400** ("startIndex 0 must be less than endIndex 0"). Guard every clear: fetch text state first, only emit deleteText for shapes that have text. Same root cause makes `gog slides update-notes` fail on slides with empty notes.
- **Speaker notes need a second phase**: notes BODY shape ids for slides you just created are auto-generated (`SLIDES_API..._N`) and unknown until after the create batch. Batch 1: slides. Then fetch `slides(objectId,slideProperties.notesPage.pageElements(objectId,shape(placeholder,text.textElements)))`, find `placeholder.type==BODY`, batch 2: notes insertText.
- **Styled metric pattern** (big number + label + detail, one editable text box): `createShape` TEXT_BOX -> `insertText` with `"$3.2\nPER 1K QUERIES\nDetail sentence."` -> per-line `updateTextStyle` with `FIXED_RANGE` indices computed from the string lengths (number: Geist bold 34pt Orange; label: Geist 10pt Gray uppercase; detail: Geist 11pt Off-Black).
- Dark dashboard screenshots (Grafana) work fine as evidence on light slides; size them from the PIL pixel aspect (`h = w / aspect`), don't eyeball.
- **Font check**: not every Google-Fonts family exists in the workspace. Geist yes; **Geist Mono no** (silently falls back to Courier — visible in thumbnails). Verify big numbers in a thumbnail before styling everything.

## gog-only limits (when not using gslides.py)

- `--convert-to` cannot combine with `--replace`; `--replace` refused for native Google files.
- gog can only: `replace-text`, `insert-text`, `replace-slide` (image swap), `add-slide` (append full-bleed image at end), `delete-slide`, `update-notes`, `read-slide`, `thumbnail`, `drive comments list`.
- Old workaround (append image slides for the user to reposition) is **obsolete** — use `gslides.py batch` instead.

## Reading reviewer feedback

```bash
gog --account <email> drive comments list <id> --json
```
Returns author, content, `quotedFileContent` (anchor), and replies. Map each comment to a slide and act.

## Recipe (new deck)

1. Auth (above). 2. Install Geist. 3. Extract/confirm palette from the style guide.
4. Render charts (matplotlib + `dune_style.py`, CSV per chart) and diagrams (graphviz, Geist).
5. `build_deck.py` (python-pptx): title/takeaway top-left, chart/body below, speaker notes. Keep it the source of truth.
6. `gog drive upload deck.pptx --convert-to slides`.
7. `thumbnail` each slide, iterate on `build_deck.py`, re-upload (new file) until right.
8. Share the final link; delete orphan intermediate decks (`drive delete <id> --force`).

## Recipe (slides in an existing shared deck)

1. `gslides.py get <deck>` — map slides, find your anchor objectIds, inspect peers' slides for the house layout (which layoutId, where titles/bodies sit, fonts/sizes).
2. Write an idempotent `build_*_slides.py` that emits batchUpdate requests: fill reserved placeholders, `createSlide` with the house layout + placeholderIdMappings, styled metric text boxes (Geist bold, brand palette), images via Drive-shared URLs.
3. Run, then `gslides.py thumbnail` **every touched slide** and read the PNGs — the review loop catches real bugs (title/body overlap, font fallback, label wrap); iterate on the script.
4. Set speaker notes (phase 2). Clean up temp Drive shares when the deck is final.

Worked example (full 6-slide build, all patterns above): `examples/build_shared_deck_slides.py` (frozen copy; deck-specific IDs, adapt before use).

Content discipline that survived review: **one number theme per slide, <=5 across the talk**; put the plan-vs-actual and if-asked numbers in speaker notes, not on slides; a chart beats a second metric box.

## Gotchas

- pptx text written with literal `\u2014` escapes vs real chars: when find/replacing in source files, match the exact byte form.
- Thumbnails max at 1600x900 — fine for review, mediocre for projection; prefer the converted native deck for the real thing.
- Date-range en-dash OK; clause em-dash not.
- Don't keep multiple "Copy of" decks around — delete orphans to avoid reviewer confusion.
