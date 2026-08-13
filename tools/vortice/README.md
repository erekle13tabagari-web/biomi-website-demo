# Vortice page generator

The 32 Vortice product pages, the Vortice hub and the Ventilation category page
are **generated**, not hand-written. Edit these scripts and re-run them; do not
edit `products/vortice-*.html` directly, or the next run will overwrite you.

Run everything in order with:

```powershell
.\tools\vortice\run-all.ps1
```

## Sources

| What | Where |
|---|---|
| Specs (airflow, power, diameter, dB) | `C:\Users\Designer\Desktop\Vortiche Tecnical Price.xlsx` |
| Photography | `…\2026\პროდუქტები\ვენტილაცია\Vortice` |

Both paths are constants at the top of the scripts that use them.

The datasheet PDFs in the library are **not** a usable source. `pdftotext`
mis-pairs labels and values wherever a label wraps — code 11201 reads as
25 m³/h against a true 90 — and positional pairing is worse. Everything numeric
comes from the price list.

## Pipeline

| Step | Script | Does |
|---|---|---|
| 1 | `vortice-sheet2.ps1` | Reads the price list → `vortice-models.json` (94 models) |
| 2 | `vortice-build.ps1` | Scans the library, joins photos to models → `vortice-final.json` |
| 3 | `vortice-assign.ps1` | Assigns each model to a page by name prefix → `vortice-pages.json` |
| 4 | `vortice-images.ps1` | One pooled gallery per page → `main/front/angle/detail/room.avif` |
| 5 | `vortice-images2.ps1` | Per-model galleries where the photos really differ → `s2-1.avif`… + `vortice-galleries.json` |
| 6 | `vortice-gen.ps1` | Writes the 32 product pages |
| 7 | `vortice-hub.ps1` | Writes `vortice.html` and `ventilation.html` (+ `-en`) |

`vortice-families.json` holds the page list: slug, which library folders feed
it, the Georgian and English copy, and the model-name pattern that decides
which models land on it. **This is the file to edit** to change wording, add a
page, or re-group models.

Diagnostics, not part of the pipeline:

- `vortice-imgsets.ps1` — reports how many genuinely distinct photo sets each page has
- `vortice-diff.ps1` — compares the library against what the site was built from; run this first when the folder has been reorganised

## Things that will bite you

**Explicit sheet columns.** Step 1 maps columns per worksheet rather than
detecting them. Content detection silently produced empty model names for 21 of
94 rows. If a new sheet appears, add it to `$COLS`.

**Recursive image scans.** Lifestyle shots live in `საიმიჯო` subfolders inside
each model folder. A flat listing drops them and silently changes which models
look alike.

**The library reuses files heavily.** The entire `MF` folder holds one model's
photos — which are actually the `MG`. Images are chosen by the product line in
the *filename*, not the folder, via `imgfilter` in `vortice-families.json`.
Grouping uses distinct content hashes, so a stray `foo (1).jpg` duplicate does
not fake a separate gallery.

**Off-limits folders** are matched by wildcard (`*DO NOT TOUCH*`), not exact
name, because that folder has already been renamed once.

**PowerShell 5.1**: these files need a UTF-8 BOM for the Georgian literals, and
`return @(...)` unrolls a one-element array to a scalar — wrap at the call site.

## After regenerating

```powershell
.\build-search-index.ps1     # product cards feed the site search
.\tools\linkcheck.ps1        # every internal href and src must resolve
```
