# Boiler pages (ქვაბი / Boilers)

Status: **model data extracted, pages not yet generated.**

## Sources

| What | Where |
|---|---|
| Codes, names, country | `products-codes.xlsx` (copy of `Desktop\29,04,2026 Products with Codes.xlsx`) |
| Photography | `…\2026\პროდუქტები\ქვაბები` |
| Specs | official manufacturer sites, per range — see below |

Run `1-extract-models.ps1` to rebuild `boilers.json` (46 boilers, 3 brands).

The workbook's boiler sheet is **four brands side by side**, not stacked:
Beretta in B–E, Riello in H–K, Warmhaus in N–Q, Teknix from T. Boilers and
their accessories share those columns, so a row only counts when it says
`ქვაბი` and isn't a thermostat, flue, pump, flange, sensor or cascade kit.

## Decisions already taken — do not silently reverse

- **Teknix is excluded.** The sheet lists five Teknix electric boilers; they are
  not going on the site. The column is not read at all.
- **VIWA 125 and VIWA 150 are included** even though the workbook omits them.
  They exist in the photo library and two pump accessories reference them, so
  the list is simply behind.
- **RESIDENCE HM 25 KIS is excluded** — the name says `ბუტაფორია`, a display
  dummy, not a sellable boiler. It has a photo folder and would otherwise have
  become a product page.
- **Warmhaus kit/plain pairs are one product, two codes.** Most Warmhaus rows
  appear twice, a `(კომპლექტში)` kit SKU and a plain one with different internal
  codes but the same boiler. The workbook only fills manufacturer code and
  country on the kit row.
- **Off-limits folders** are marked `DONT TOUCH CLAUDE` here — note the spelling
  differs from `DO NOT TOUCH` in the Mitsubishi and Vortice libraries, so the
  guard has to match both.

## Page structure — 14 series, both languages

| Brand | Series |
|---|---|
| Beretta | Ciao S · City · Mynute S · Quadra Green · Power Evo-X · Power Max |
| Riello | Start KIS · RLT · Condexa Pro |
| Warmhaus | Lawa · Lawa Plus · Lawa System · Viwa · Viwa S |

One page per series with model chips, as with Vortice.

### The Lawa family

The photo folders are grouped by **output**, not by product:
`Lawa 24_HO 24 SYSTEM_SYSTEM 24` holds one photo set shared by three separate
products — LAWA 24, LAWA SYSTEM 24 and LAWA HO 24 SYSTEM. Same for 28 and 32.
Keep the products distinct on their pages and let them share the gallery; the
hash-based grouping used for Vortice already does this.

## Specs

There is no spec sheet. The workbook carries identity only — code, name,
manufacturer code, country — and no kW, efficiency or DHW figures.

What may be published:

- **kW from the model number** (CITY 24 -> 24 kW) — standard across all three brands
- **Real figures from the official per-range PDFs**, which do have text layers,
  for the ranges that exist on the manufacturer sites

What must stay blank rather than be invented:

- **City, Quadra Green and Mynute 35 S** are not on berettaheating.com at all —
  they are outside Europe and older stock, still held here.
- **12 of 20 Warmhaus PDFs have no text layer**, being image-only scans.
- The Beretta **City** folders contain a **CIAO S** brochure, so documents are
  not reliably matched to their models. Do not read specs across that gap.
- Nothing found defines C.S.I. / R.S.I., so neither "combi" nor "system" goes on
  a page as fact until it is sourced.

## Remaining work

1. Map models to photo folders, convert imagery
2. Generate the 14 series pages in both languages
3. Brand hubs for Beretta, Riello, Warmhaus
4. The ქვაბი category listing, built the same way as `tools/build-category-pages.ps1`
5. Menu wiring — ქვაბი already lists all three brands
6. `build-search-index.ps1`, `tools/build-meta.ps1`, `tools/linkcheck.ps1`

## Emtaş (added 2026-09-24)

Emtaş solid fuel boilers, bought through Sakra (sakra.com.tr sells Emtaş: the
model codes, the photos and the copy are all Emtaş's). Only 45-100 kW sizes.

- **Data:** `emtas.json` — figures read off the technical-table images on
  sakra.com.tr (the file names each range's sheet). `emtas.ps1` turns it into
  model records (for `2-images.ps1`) and spec rows (for `3-pages.ps1`).
- **Output is `.kw` on every record.** The number in an Emtaş model name is
  thousands of kcal/h (EK3G-60 is 70 kW), so it must never be read as kW.
- **Photos:** `ქვაბები\Emtas\<range>\a,b,c.jpg`, cleaned copies. Sakra's
  originals with Turkish badges sit in each folder's `სხვა - ...` subfolder,
  which `2-images.ps1` skips.
- **Floor:** `visible.ps1` went from 50 to 45 kW for Emtaş's 47 kW sizes; no
  other brand has anything between 45 and 49.
- **Left out on purpose:** EKY/3K-45 depth (sheet says 9100 mm), EKYB/S weight
  and water (copied from a smaller boiler on the sheet), ranges 11 and 16 (no
  table published).
- **Fuel filter:** every boiler family carries `fuel` (gas / solid / burner);
  Emtaş families also `feed` (manual / auto). `4-hubs.ps1` stamps them on the
  cards; the boilers category filters on fuel, the Emtaş hub on both.

Regenerating the family pages wipes what later steps added. After
`3-pages.ps1` / `4-hubs.ps1`, run in order: `tools/add-card-brands.ps1`,
`tools/brand-links.ps1`, `tools/docs/3-pages.ps1` (the PDF download lists),
`tools/build-category-pages.ps1`, `tools/build-meta.ps1`, `build-search-index.ps1`.

### Emtaş is a test-site preview (since 2026-09-25)

`$PREVIEW = @('emtas')` in `visible.ps1` keeps Emtaş on test.biomi.ge only while
its range and wording are settled. Its pages and hub are still built, but the
boilers and heating listings, the menu (the entry carries `"preview":"emtas"`
in `tools/menu-tree.json`), search, the sitemap and other pages' related cards
leave it out, and `tools/deploy/deploy-site.ps1` uploads its files to the test
site only. The boilers and heating descriptions switch on the same flag in
`tools/build-category-pages.ps1` (`$EMTAS_LIVE`).

**To publish Emtaş:** set `$PREVIEW = @()`, run the full rebuild listed above
plus `tools/menu-rebuild.ps1`, then Update Website and both uploads. Preview
link while it lasts: https://test.biomi.ge/products/emtas.html
