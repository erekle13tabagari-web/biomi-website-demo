# News

Two steps, same shape as `tools/projects`.

```powershell
powershell -File tools\news\1-images.ps1     # heroes, galleries, inline figures
powershell -File tools\news\build-news.ps1   # the four pages + the homepage rail
```

## Adding an article

1. Drop a folder into `Biomi Web NEWS/` named exactly as it will appear in
   `news.json`'s `src`. Inside it:
   - `thumbnail.*` — becomes the hero, cropped to 16:9
   - `Main gallery/` — optional, becomes the thumbnail strip
   - `DO NOT USE/` — never read
   - the `.docx` — the copy, and a possible source for captioned photos
2. Add an entry to `news.json`. Both languages, `body` as an array of HTML
   lines.
3. Run the two scripts. Then `tools\build-meta.ps1` and
   `build-search-index.ps1`, and add the article to the static list in the
   latter.

Nothing stores a count: the gallery is whatever is in the folder, the homepage
rail and the "other news" strip at the foot of each article are whatever is in
`news.json`. Both are rebuilt from one card lifted out of the page being
edited, so the markup, labels and inline SVGs stay exactly as designed rather
than being retyped here.

## Captioned figures

A line in `body` that is exactly `FIGURE` becomes the next entry from the
item's `figures` list, in order, with that language's `alt` and `cap`.

Each figure names its own source, because they do not all live in the same
place:

```json
{ "from": "docx:image2", "img": "news-duct-production-kartlisi.jpg", … }
{ "from": "წრე.jpg",     "img": "news-duct-production-tsre.jpg",     … }
```

- `docx:imageN` — the Nth inline shape inside the Word file. Some captioned
  photos exist only there, placed against their caption by the author and
  nowhere else. `image1` is normally the hero.
- anything else — a file sitting in the article folder.

Naming the source per figure is what keeps a caption tied to the photo it was
written for.

A `FIGURE` marker with no figure left to spend is dropped. That is how a
withdrawn photo takes its caption out of the article with it, rather than
leaving the caption to be paired with some other picture.

## Templates

`_template.html` / `_template-en.html` supply the header, drawer, footer and
every relative path. They live here rather than in `news/` so they are never
served, never tagged by `build-meta.ps1`, and never reach the sitemap —
`linkcheck.ps1` skips `tools/` for the same reason, since their `../` links
resolve against the wrong folder.

To move the layout on, edit a template and re-run.
