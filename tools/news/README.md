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
   - the `.docx` — the copy, and the source of any captioned inline photo
2. Add an entry to `news.json`. Both languages, `body` as an array of HTML
   lines. A line that is exactly `FIGURE` becomes the captioned inline photo
   described by that language's `figure` block; leave `figure` out and the
   marker is dropped.
3. Run the two scripts. Then `tools\build-meta.ps1` and
   `build-search-index.ps1`, and add the article to the static list in the
   latter.

Nothing stores a count: the gallery is whatever is in the folder, the homepage
rail and the "other news" strip at the foot of each article are whatever is in
`news.json`. Both are rebuilt from one card lifted out of the page being
edited, so the markup, labels and inline SVGs stay exactly as designed rather
than being retyped here.

## Why the inline figure comes out of the .docx

The captioned photos are not in the folder — the author placed each one against
its own caption inside the Word file. Pulling `word/media/image2.*` out of the
`.docx` is what guarantees the caption still describes the photo above it.

`image1` is the hero and `image3`, in the ductwork article, is the shot that was
later moved to `DO NOT USE`; that figure and its caption are both left out.

## Templates

`_template.html` / `_template-en.html` supply the header, drawer, footer and
every relative path. They live here rather than in `news/` so they are never
served, never tagged by `build-meta.ps1`, and never reach the sitemap —
`linkcheck.ps1` skips `tools/` for the same reason, since their `../` links
resolve against the wrong folder.

To move the layout on, edit a template and re-run.
