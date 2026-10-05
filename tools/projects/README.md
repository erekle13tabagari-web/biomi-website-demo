# Projects

Each project is one file: `content/projects/<slug>.json`. Since 2026-10-01 they
are written through the editor at `https://test.biomi.ge/admin` (Decap CMS, see
`admin/`) like the news, and GitHub builds the pages and puts them on the test
site. Nothing reaches biomi.ge until the designer publishes as usual.

```powershell
powershell -File tools\projects\2-images.ps1        # pictures (-UploadsOnly: editor uploads only)
powershell -File tools\projects\build-projects.ps1  # the pages, the homepage cards, projects.html
```

Then `tools\build-meta.ps1` and `build-search-index.ps1`, which the GitHub
build and `Update Website.bat` both run anyway.

## The project file

```json
{
  "slug": "oro",                               // the address: projects/oro.html
  "order": 3,                                  // place on the homepage; 1 is the big first card
  "hero": "/assets/img/proj-oro.jpg",          // or an upload in /assets/img/uploads/
  "logo": "/assets/img/clients/oro.svg",       // optional
  "lockup": true,                              // a near-square logo: the taller chip
  "logoHeight": 34,                            // optional, px; otherwise 22 (wide) / 42 (lockup)
  "video": "https://www.youtube.com/watch?v=…",// optional, shown below the text
  "gallery": ["/assets/img/uploads/a.jpg"],    // optional; uploads replace the folder gallery
  "src": "Oro",                                // the photo folder under "Projects files"
  "ka": { "h1": "", "sub": "", "cat": "", "lead": "", "body": "Markdown",
          "alt": "", "cap": "", "crumb": "", "card": "", "title": "", "desc": "" },
  "en": { … }
}
```

- `body` is the news Markdown (`tools/markdown.ps1`): paragraphs, `##` / `###`
  headings, bold, italic, links, lists, and quotes. A quote's last line
  starting with a dash names who said it, printed as `- name` as the project
  pages always have.
- Left empty: `crumb` = the headline, `card` (the name on the homepage card) =
  `crumb`, `alt` = the headline, `title` = headline + " - ბიომი", `desc` = the lead.
- `order` sorts the homepage rail and `projects.html`; equal numbers go by slug.
- Delete the file and the next build deletes the project's two pages and card.

## How the pages are built

`build-projects.ps1` writes the whole article from the file. The page around
it (head, header, drawer, footer, the breadcrumb's first steps and the closing
row) is taken from an existing project page - Terminal's, or any other if that
one is gone - so it follows the rest of the site's layout. Blocks a project
does not have (logo, gallery, video, caption) are not written at all.

The homepage cards (`index.html`, `index-en.html`) are rebuilt from the same
files, and `build-index.ps1` copies them onto `projects.html`. A card names its
photo in `data-bg`; `main.js` sets it once the rail is near the screen.

Until 2026-10-01 five projects lived in `tools/projects/projects.json` and
ORO, PASHA and Terminal were pages written by hand; all eight were moved into
`content/projects/` with their texts unchanged. The per-logo heights that used
to sit in style.css by file name are `logoHeight` now.

## Pictures

Uploaded in the editor, a picture lands in `assets/img/uploads/` and
`2-images.ps1` converts it into the project's own names:
- the hero becomes `proj-<slug>.jpg` (16:9, 1600×900), with a full-size AVIF
  twin for the page and a 1400px `-card.avif` for the cards;
- the logo becomes `clients/<slug>.svg` (an SVG as it is) or `clients/<slug>.png`;
- the gallery becomes `assets/img/<slug>-gallery/<slug>-<n>.avif`. Removing
  every uploaded gallery photo removes the gallery.

Since 2026-10-05 a gallery photo is made at 2400px, quality 75 (it was 1600px
at 48, which visibly smoothed detailed photos), plus a 280px-tall copy in
`<slug>-gallery/thumb/`. The page's strip shows the copy and the lightbox
opens the full photo (`data-full`). The hero's AVIF is quality 72, made from
the source. Galleries made before then (all but Tsre) keep their old files
until their photos are made again.

`assets/img/uploads/_processed.json` (shared with the news) records what was
made from what, so a picture is converted again only when it is replaced.

On the office computer the project folders under `Projects files/` still
work: `thumbnail.*` is the hero and `Main gallery/` the gallery, made again only
when a source photo is newer than what it made. `DO NOT USE/` is never read.
Editor uploads win over the folder.

## Assets still missing

- **culinary** — no photograph. `assets/img/proj-culinary.jpg` is a generated
  brand plate standing in for the hero; upload a photo in the editor and the
  page and both cards update.
