# Water-heater page generator

Builds the ბოილერები (water heater / cylinder) pages the same way
`tools/boilers` builds the ქვაბი pages. Read that README first — the shape is
identical and only the differences are recorded here.

## Sources

| What | Where |
|---|---|
| Model list, codes, origin | `products-codes.xlsx`, sheet **ბოილერები** |
| Photography | `…\2026\პროდუქტები\ბოილერები` (see `config.ps1`) |
| Omega figures | <https://www.omegaboyler.com.tr/en> |

The sheet lays three brands side by side rather than stacking them — Beretta in
A–E, Riello in G–K, Omega in M–Q — each block being
(#, internal code, name, manufacturer code, country).

## Pipeline

| Step | Script | Does |
|---|---|---|
| 1 | `1-extract.ps1` | sheet ბოილერები → `water-heaters.json` (25 products) |
| 2 | `2-images.ps1`  | assigns models to pages, builds galleries → `wh-pages.json`, `wh-galleries.json` |

Steps 3 (pages) and 4 (hub / category listing) are **not written yet**.

## Settled questions

Confirmed by the owner on 18 Aug 2026, so they do not need asking again:

- **The seven ESB renders are only two distinct images.** Several source files
  are byte-identical. That is correct and matches Omega's own site, which shows
  one visual for the whole single-coil range regardless of litre size.
- **The Riello 7200.200NV is a 200-litre cylinder.** Confirmed by the owner;
  the sheet does not say so, and the litre figure is not derivable from the
  model name alone.
- **Why ECSB / AKM / OBF are on a placeholder.** Not because the visual is
  shared with ESB — checked, and it is not. Omega publishes a *different*
  photograph per coil type: `tek-serpantinli-boyler.jpg` for single coil,
  `cift-serpantinli-boyler.jpg` for double. Reusing the ESB render would show
  customers the wrong tank. The correct images exist on omegaboyler.com.tr and
  simply are not in the library yet; drop them into the family folder root and
  re-run step 2.
- **ECSB400 is absent from the sheet** — the range jumps 300 → 500 and internal
  code 61014 is skipped. Unresolved: nobody knows yet whether that is a hole in
  the sheet or in the range. Do not invent the model.

## Things that will bite you

**PowerShell is case-insensitive about variable names.** `$names` inside a loop
silently clobbered the module-level `$NAMES` array, and the family gallery came
out written as `m7-1.avif` instead of `main.avif`. The per-model variable is
called `$mnames` for exactly this reason.

**Excluded folders are matched segment by segment**, not with a regex over the
whole path. The names are Georgian and the separators are backslashes; a path
regex combining the two is unreadable and was wrong twice before this.
