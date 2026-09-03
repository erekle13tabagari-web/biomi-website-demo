# Project pages

`projects.json` holds the copy, `build-projects.ps1` renders it into
`projects/<slug>.html` and `projects/<slug>-en.html`.

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/projects/build-projects.ps1

Chrome (header, footer, drawer, breadcrumbs, video block) is cloned from
`projects/terminal.html`, which is the newest page and therefore carries the
current layout. If the layout changes, change it on the Terminal page first and
re-run this — the generator will pick it up. The output lands in the same folder
as the template, so every relative path stays valid.

After a run, re-run these two from the repo root so the new pages are tagged and
findable:

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-meta.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File build-search-index.ps1

`build-projects.ps1` strips the `meta:start … meta:end` block it inherits from
the template (it would otherwise carry Terminal Towers' canonical URLs), so
`build-meta.ps1` has to run afterwards to write a correct one.

## Fields

| field    | meaning |
| -------- | ------- |
| `slug`   | file name, and the `?brand=`-free page URL |
| `hero`   | file in `assets/img/`, also the homepage card background via `.proj--N` in style.css |
| `logo`   | file in `assets/img/clients/`. Leave empty and the logo chip is dropped rather than left broken |
| `logosq` | `true` for a near-square mark, which needs `.proj__logo--sq` to avoid rendering as a 20px dot |
| `video`  | YouTube id |
| `ka`/`en`| per-language `cat`, `crumb`, `title`, `desc`, `h1`, `sub`, `alt`, `cap`, `lead`, `body` |

`body` is an array of lines, joined verbatim — an empty string is a blank line.
It is raw HTML, so links and `<blockquote>` work as written.

## Galleries

The generator drops the template's `.gallery` block. Photos for four of the
projects are not sorted yet, and a strip of grey placeholders reads as a broken
page. To add a real gallery, paste the block back between the hero `<figure>` and
`.article__body` — copy the shape from `terminal.html`, which the lightbox and
the edge-fade script both pick up automatically.

## Assets still missing

- **culinary** — no photograph and no client logo. `assets/img/proj-culinary.jpg`
  is a generated brand plate standing in for the hero; replace the file and the
  page and the homepage card both update. Set `logo` once a mark exists.
