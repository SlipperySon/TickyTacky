# Design Language

**Default theme locked:** Classic Notebook  
**Themes:** one shipping theme now; user-selectable themes later (architecture reserved, not implemented in MVP).

App context: dense personal planner (tasks + timetable). Cozy / classic notebook — not a marketing site, not “AI cream + terracotta + big serif.”

Related: [`MEM.md`](MEM.md) · [`SCOPE.md`](SCOPE.md)

---

## Principles

1. **Notebook first** — warm paper, graphite ink, soft ruled lines; feels like an open planner
2. **Pastel with purpose** — sage green + sky blue as the accent pair; pastels for lists/tags/blocks, not neon
3. **Cozy ≠ cluttered** — soft and approachable, still dense and fast to scan
4. **Density with air** — list rows, not card stacks; shadows rare
5. **Schedule ≠ tasks** — timetable blocks read like washi / highlighter strips on the page
6. **One theme now** — all UI built against Classic Notebook tokens; theme switching is a later feature
7. **Avoid clichés** — no purple glow, no terracotta hero accent, no broadsheet layout, no Inter/Roboto branding

---

## Theme system (MVP vs later)

### MVP
- Ship **only** Classic Notebook (light)
- Dark mode: **mapped Notebook dark** (same theme, dimmed paper) — system appearance, not a separate selectable theme yet
- Hard-code tokens in `DesignTokens` / `Theme.notebook`

### Later (P1/P2 — do not build now)
- Settings → **Appearance → Theme**
- Themes are swappable token packs (same components, different colors/radii/line style)
- Persist `selectedThemeID` on user settings (API-backed when sync exists)
- Candidate future packs (placeholders only):

| Theme ID | Intent |
|----------|--------|
| `notebook` | Default — warm paper, pastel sage/sky *(shipping)* |
| `graphite` | Cool gray, sharper green (old candidate A) |
| `ink` | Higher contrast, cooler, less beige |
| `midnight` | True dark-first (not just inverted notebook) |

Components must read colors from a **theme token API**, never raw hex in views — so future themes don’t require UI rewrites.

```text
View → ThemeTokens.current.accent
     → (MVP: always NotebookTokens)
     → (Later: switch on selectedThemeID)
```

---

## Locked theme: Classic Notebook

**Mood:** Open paper planner. Soft beige page, pencil graphite writing, pastel sage + sky stickers. Cozy-core adjacent, but **classic stationery** more than cottage aesthetic.

### How this stays “notebook” not “generic AI cream”
- Accent pair is **sage + sky**, never terracotta/rust
- UI type is **SF Pro** (readable density); brand may use a soft rounded grotesque — not a huge high-contrast serif headline system
- “Notebookness” comes from **paper tone + ruled separators + margin cues + pastel chips**, not from serif everywhere

### Core palette

| Token | Hex | Role |
|-------|-----|------|
| `canvas` | `#F3EBDD` | App background — notebook paper (warm beige, slight tooth) |
| `canvasRuled` | `#E5DCCE` | Subtle vertical margin / gutter hint |
| `surface` | `#FBF6EC` | Elevated sheets, editors, grouped panels |
| `surfaceInk` | `#FFFCF6` | Task row wash / inputs |
| `ink` | `#2A2622` | Primary text — warm graphite |
| `inkMuted` | `#7A7268` | Secondary text, metadata |
| `inkFaint` | `#A39A8E` | Placeholders, completed |
| `rule` | `#D4CBBA` | Hairline row separators |
| `ruleNotebook` | `#C5D4E0` | Soft blue notebook ruling (timetable hour lines, section rules) |
| `accent` | `#7FAF98` | Primary actions, completed check — **pastel sage** |
| `accentPressed` | `#6B9A84` | Pressed sage |
| `accentSoft` | `#E2F0E8` | Sage wash (selected row, chips) |
| `accentSecondary` | `#8BB4C9` | Links, info, secondary CTAs — **pastel sky** |
| `accentSecondarySoft` | `#E0EEF5` | Sky wash |
| `todayMark` | `#8BB4C9` | “Today” / now indicator (sky) |
| `danger` | `#C46B5D` | Delete / errors (soft clay, not alarm red) |
| `overdue` | `#C47A6C` | Overdue emphasis |
| `warning` | `#D4B56A` | Medium caution |

### Priority (dots + label weight; not color alone)

| Priority | Dot | Notes |
|----------|-----|--------|
| None | `#A39A8E` | Faint graphite |
| Low | `#8BB4C9` | Pastel sky |
| Medium | `#D4B56A` | Soft pencil yellow |
| High | `#E0A37A` | Soft apricot (not terracotta hero) |
| Urgent | `#C47A6C` | Dusty rose |

### List / tag / timetable swatches (curated pastels)

MVP picker set — classic sticker palette:

| Name | Fill | On-fill text |
|------|------|--------------|
| Sage | `#7FAF98` | `#1F2E28` |
| Sky | `#8BB4C9` | `#1E2C34` |
| Lilac | `#B7A7C9` | `#2A2433` |
| Blush | `#E2B6AE` | `#3A2826` |
| Butter | `#E5D39A` | `#3A3420` |
| Mist | `#B8C9C1` | `#24302C` |
| Slate | `#A3AAB3` | `#24262A` |
| Kraft | `#C4A882` | `#2E261C` |

Timetable blocks: use swatch fill at ~88% opacity on paper; title in on-fill color; corner radius 5–6pt (soft sticker, not pill).

### Typography

| Role | Face | Notes |
|------|------|--------|
| UI body / lists | **SF Pro Text** | Default Apple density |
| UI rounded moments | **SF Pro Rounded** | Section headers, empty-state title — cozy without custom font dependency |
| Brand wordmark | **SF Pro Rounded** Semibold *or* later **Nunito / Rounded** if we add a bundled font | No giant serif poster type in-app |
| Times / timetable | **SF Mono** or SF Pro tabular | Aligned columns |

### Shape & line

| Element | Spec |
|---------|------|
| Task row | Flat on paper; `rule` hairline; **no card shadow** |
| Checkbox | 18pt rounded square (r=5); sage fill when done |
| Chips / tags | r=6, pastel soft fills |
| Sheets / modals | r=12–14, `surface` fill |
| Notebook margin | Optional 12–16pt leading gutter with `canvasRuled` on Today/Timetable only |
| Hour lines | `ruleNotebook` at low opacity |

### Motion

- Complete: 120ms check + 200ms soft fade to `inkFaint`
- Quick add present: gentle 200ms (easeOut), no bounce
- Timetable day change: short cross-fade; respect Reduce Motion

### Dark mapping (system — same theme family)

Not a separate selectable theme in MVP. Rough map:

| Light | Dark |
|-------|------|
| `canvas` `#F3EBDD` | `#1C1A17` |
| `surface` `#FBF6EC` | `#26231F` |
| `ink` `#2A2622` | `#EDE6DA` |
| `rule` `#D4CBBA` | `#3A3530` |
| `accent` `#7FAF98` | `#8FBFAB` |
| `accentSecondary` `#8BB4C9` | `#9BC0D1` |

---

## Component rules

| Element | Rule |
|---------|------|
| Task row | Full-bleed; graphite title; sage checkbox |
| Completed | `inkFaint` + optional strikethrough |
| FAB / Quick add | Sage fill **or** graphite fill + sage check accent — pick one primary |
| Timetable | Paper grid + pastel sticker blocks; sky “now” line |
| Tab bar | Paper/surface; selected = sage or graphite weight |
| Empty states | SF Rounded title + one sage/sky line; no illustration required for MVP |
| Settings | Grouped inset lists on `surface` |

---

## Surfaces to prove the theme (order)

1. Today (paper + ruled + sage checks + sky schedule chips)
2. Task row + detail editor
3. Weekly timetable (pastel blocks)
4. Lists + tags (swatches)
5. Quick add
6. Empty inbox / launch

---

## Decision log

| Field | Value |
|-------|--------|
| App name | **Tickytacky** |
| Chosen theme | **Classic Notebook** (`notebook`) |
| Locked | 2026-08-19 |
| Accent pair | Pastel sage `#7FAF98` + pastel sky `#8BB4C9` |
| User theme picker | **Later** — token API now, UI later |
| Token source of truth | This file → Swift `NotebookTokens` (+ CSS vars when web exists) |

---

## Next

1. Keep implementing against Classic Notebook only
2. When coding UI: introduce `ThemeTokens` protocol with single `NotebookTokens` conformer
3. Theme picker screen = parked until after MVP daily-driver polish
4. Optional: static mock / SwiftUI preview of Today in this palette before foundation coding
