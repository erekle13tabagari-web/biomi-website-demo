# News

Each article is one file: `content/news/<slug>.json`. Since 2026-09-22 the
marketing manager and the designer write them through the editor at
`https://test.biomi.ge/admin` (Decap CMS, see `admin/`), and GitHub builds the
pages and puts them on the test site. Nothing reaches biomi.ge until the
designer publishes as usual.

```powershell
powershell -File tools\news\1-images.ps1                # pictures (-UploadsOnly: editor uploads only)
powershell -File tools\news\build-news.ps1              # the pages, the homepage rail, "other news"
```

Then `tools\build-meta.ps1` and `build-search-index.ps1`, which the GitHub
build and `Update Website.bat` both run anyway.

## The article file

```json
{
  "slug": "new-office",                       // the address: news/new-office.html
  "date": "2026-10-01",
  "hero": "/assets/img/uploads/photo.jpg",    // or a finished picture in assets/img
  "gallery": ["/assets/img/uploads/a.jpg"],   // optional
  "figures": [ { "image": "...", "ka": { "alt": "", "cap": "" }, "en": { … } } ],
  "ka": { "h1": "", "cat": "", "lead": "", "body": "Markdown", "alt": "", "cap": "",
          "title": "", "desc": "", "crumb": "", "dateText": "" },
  "en": { … }
}
```

- `body` is simple Markdown: paragraphs, `##` / `###` headings, bold, italic,
  links, bullet and numbered lists. `tools/news/load-news.ps1` turns it into
  the page's HTML. That is the whole list, and it matches the editor's buttons.
- A paragraph that is exactly `FIGURE` becomes the next entry from `figures`,
  in order, with that language's `alt` and `cap`. A `FIGURE` with no figure
  left is dropped.
- `title`, `desc`, `crumb` and `dateText` may be left empty: they default to
  the headline + " - ბიომი", the lead, the headline, and the date written out.
- The homepage rail and each article's "other news" strip show the newest
  three. Every article keeps its own page.
- Delete the file and the next build deletes the article's two pages.

## Pictures

Uploaded in the editor, a picture lands in `assets/img/uploads/` and
`1-images.ps1` converts it into the article's own names:
- the hero becomes `news-<slug>.jpg`, cropped to 16:9 at 1600×900, with a full-size AVIF twin and a 900px card copy;
- each figure becomes `news-<slug>-fig<n>.jpg` + `.avif`;
- the gallery becomes `assets/img/<slug>-gallery/<slug>-<n>.avif`.

`assets/img/uploads/_processed.json` records what was made from what, so a
picture is converted again only when it is replaced. The originals are kept
in the repository but not uploaded to the server.

The two first articles were built from folders in `Biomi Web NEWS/` on the
office computer. Their `src` field names the folder. There, `thumbnail.*` is
the hero, `Main gallery/` the gallery, and a figure's `from` names its source:
a file in the folder, or `docx:imageN`, the Nth picture inside the Word file.
`DO NOT USE/` is never read. Without that folder (on GitHub's build machine,
or with `-UploadsOnly`) those two are left exactly as they are.

## Templates

`_template.html` / `_template-en.html` supply the header, drawer, footer and
every relative path. They live here rather than in `news/` so they are never
served, never tagged by `build-meta.ps1`, and never reach the sitemap.
`linkcheck.ps1` skips `tools/` for the same reason, since their `../` links
resolve against the wrong folder.

To move the layout on, edit a template and re-run.
