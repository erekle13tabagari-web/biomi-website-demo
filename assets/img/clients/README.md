# Client logos — "ჩვენი ნამუშევრები" projects

Drop each client's logo here, then point the matching card's `.proj__logo` at it in `index.html`.

Suggested filenames (used in the comments in index.html):
- `oro.svg`        → ORO card
- `chateau.svg`    → შატო card
- `kingscity.svg`  → მეფის ქალაქი card
- `sdsu.svg`       → SDSU card

## How to swap in a real logo
Replace the placeholder text inside the chip:

```html
<!-- from -->
<span class="proj__logo">ORO</span>
<!-- to -->
<span class="proj__logo"><img src="assets/img/clients/oro.svg" alt="ORO"></span>
```

Notes:
- The chip is a **white rounded badge**, so transparent-background PNG/SVG logos look best.
- The logo is auto-capped at **30px tall / 110px wide**; the chip grows to fit.
- These are the **clients'** logos (the companies the projects were done for) — not the Biomi logo.
- Or just send the files to me and I'll wire each one in.
