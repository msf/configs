---
name: google-slides
description: Build and edit on-brand Dune Google Slides decks programmatically via gog (Slides API) + python-pptx, with Geist fonts and the Dune brand palette. Use whenever the user wants to create, update, restyle, or read comments on a Google Slides presentation for Dune, or convert charts/diagrams into a deck. Covers brand extraction, chart/diagram rendering, the pptx->Slides build path, gog's edit limits, and self-verification via thumbnails.
---

# Google Slides (Dune-branded, programmatic)

Make Dune-styled decks reproducibly: matplotlib/graphviz assets -> python-pptx -> Google Slides via `gog`. Self-verify every slide with `gog slides thumbnail`. Source of truth is the build script, not the live deck.

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

## Hard limits of `gog` (decide the workflow around these)

- `--convert-to` **cannot** combine with `--replace`.
- `--replace` is **refused for native Google files** ("cannot replace content for Google Workspace files") — you cannot push an updated pptx into an existing native Slides file.
- gog has **no `batchUpdate`** — cannot create an editable text slide at a position, nor place an image freely on a slide.

What gog **can** do on an existing deck (all keep the same file/link):
- `slides replace-text <id> <find> <repl>` — edit text (global find/replace; use unique strings).
- `slides insert-text <id> <objectId> <text>` — text into an existing shape.
- `slides replace-slide <id> <slideId> <image>` — swap the image on a slide in place.
- `slides add-slide <id> <image>` — append a **full-bleed image** slide (only at the end).
- `slides delete-slide`, `slides update-notes`, `slides read-slide`, `slides thumbnail`.
- `drive comments list <id>` — read reviewer comments (author, text, anchor).

**Consequence — the editability/link trade-off:**
- **Editable native deck => must be a NEW file each build (new link).** Re-converting always makes a new file.
- **Same shared link => only in-place edits**: `replace-text` (text), `replace-slide` (chart images), and **new slides appended as images** (user drags into position). Slides added this way are not text-editable.
- Practical pattern when a link is already shared: update existing slides' images (`replace-slide`) + text (`replace-text`) in place, and **append new slides as images at the end** for the user to reposition.

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

## Gotchas

- pptx text written with literal `\u2014` escapes vs real chars: when find/replacing in source files, match the exact byte form.
- Thumbnails max at 1600x900 — fine for review, mediocre for projection; prefer the converted native deck for the real thing.
- Date-range en-dash OK; clause em-dash not.
- Don't keep multiple "Copy of" decks around — delete orphans to avoid reviewer confusion.
