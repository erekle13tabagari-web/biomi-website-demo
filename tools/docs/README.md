# Product documentation

Three scripts, run in order from the repo root:

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/docs/1-inventory.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/docs/2-compress.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/docs/3-pages.ps1

1. **1-inventory.ps1** walks the source libraries under
   `2026\პროდუქტები`, works out which product page each PDF belongs to, and
   writes `docs.json` (mapped) plus `unmapped.json` (everything it could not
   place). Nothing is copied — run this alone and read the report before
   committing to the other two.
2. **2-compress.ps1** shrinks each document into `assets/downloads/` and writes
   `published.json`.
3. **3-pages.ps1** rewrites the documents tab on all 150 product pages from
   `published.json` + `legacy.json`.

Re-runnable end to end. Adding a file to the library and running all three picks
it up; a page that loses its last document falls back to the "documentation on
request" line it started with.

## How a document finds its page

The libraries are already organised by model folder, and three generators
already know which folder belongs to which page — so `1-inventory.ps1` reads
`imgdirs` straight out of `tools/boilers/families.json`,
`tools/water-heaters/families.json` and `tools/vortice/vortice-families.json`
rather than duplicating that knowledge.

Only the air-conditioner library has no generator, so `map.json` carries a table
for it. Entries are matched with `StartsWith` and the **longest match wins**,
which is what stops `…კედლის` swallowing the documents that belong to
`…კედლის WindFree`.

Two families can also claim the *same* folder — LINEO and LINEO QUIET both
list `LINEO_Q`, MF and MFO both list `MFO_` — and a folder cannot say which
page its documents are for. Each such folder is **pinned** to one page under
`_pins` in `map.json`, and a pin beats any families.json entry for the same
folder. The script prints every shared folder on each run and warns about one
that is not pinned (it then falls back to the family declared first). Add a pin
whenever a new family reuses another's folder.

This has to be explicit because `Sort-Object` in Windows PowerShell is not
stable: sorting on length alone, the winner of a tie depended on how many
entries the table held, and adding the two Gulliver burners to
`boilers/families.json` quietly moved the LINEO_Q documents from LINEO QUIET to
LINEO.

## What is deliberately excluded

| excluded | why |
| --- | --- |
| `DO NOT TOUCH` / `DONT TOUCH` folders | off-limits |
| `პიქტოგრამები` | dimension line-drawings, not documentation |
| anything matching `price`, `прайс`, `ფასი` | commercial, must never be published |
| `Untitled*`, `* copy.pdf` | working files sitting beside the real brochure — one `Untitled-2.pdf` is a 54.7 MB duplicate of a 4.8 MB range brochure |
| `Riello Start kis.pdf`, `idra_bv_2001000.pdf` | downloaded from manualslib.com and branded on every page — third-party re-hosts of the manufacturer's manual, not ours to republish. Replace with the originals from Riello and Beretta |
| `BS1-2-3-4_2908117-4.pdf` | Riello's spare-parts catalogue for the Gulliver BS burners — part numbers for service engineers, not buyer documentation |

## Compression

Source is ~800 MB; published is ~320 MB. Images are converted to RGB and
downsampled to 110 dpi at JPEG quality 70. Two things worth knowing before
changing the settings:

* The images in these PDFs are mostly **CMYK**, and Ghostscript's downsample
  filter refuses CMYK — it prints `Failed to initialise downsample filter` and
  passes the image through untouched. The RGB conversion is not cosmetic; drop
  it and nothing downsamples at all.
* Ghostscript arguments must be built as an **array and splatted**. Written
  inline, PowerShell mangles `-sOutputFile` and Ghostscript reports `requires an
  output file but no file was specified`.

A file that comes out no smaller is copied across untouched, so an
already-optimised original is never made worse.

`overrides.json` handles documents that need more than compression — currently
one 144-page manual bound in eight languages, of which only the English pages
and the shared diagrams are published.

## Naming and labels

Vortice documents are all named for an article code, either bare
(`0000016039.pdf`) or embedded (`70_EN_16039_Libretti_Istruzioni_…`). Resolving
that code to a model name is what stops a page listing six identical
"Instruction booklet" links. The code → model table is built from the priced
model list **and** from the data sheets themselves, whose first page reads
`CODE 16039 / CA 250 V0 E` — the second source is needed because the library
holds documents for codes Biomi does not stock.

Two prefixes that are not what they look like, both confirmed by reading the
files: a bare `0000<code>.pdf` is the **Technical Data Sheet**, and `de-` is not
German but *dati energetici* — the **energy data** sheet.

`legacy.json` declares the two documents that were published under hand-written
blocks before this generator existed. They are not in the source library, so
without it, regenerating a page would drop the links 16 pages still rely on.
