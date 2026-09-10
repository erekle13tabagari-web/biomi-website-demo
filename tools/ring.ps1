# The services ring on the homepage: heading, subtitle and the seven step nodes.
#
# The ring was hand-written twice (Georgian and English) with eight nodes at
# fixed 45-degree angles. The ALL IN ONE model is seven steps, and the copy has
# been revised several times, so the content lives here instead: one edit, both
# languages, and the angles are computed from the step count rather than typed
# in. Nothing in the CSS or JS knows how many nodes there are -- .ring__node
# positions itself from its own --a, and main.js reads --a back to rotate the
# clicked node to 3 o'clock -- so changing the count is purely a markup change.
#
# Re-runnable: it replaces the node block wholesale.
$repo = Split-Path $PSScriptRoot -Parent
$BOM  = New-Object Text.UTF8Encoding($true)

$HEAD = @{
  ka = @{ h2 = 'სრული საინჟინრო ციკლი'
          p  = 'ვაერთიანებთ პროექტის ყველა ეტაპს - საინჟინრო კონცეფციიდან ტექნიკური მხარდაჭერის ჩათვლით' }
  en = @{ h2 = 'The full engineering cycle'
          p  = 'We bring together every stage of a project - from the engineering concept through to technical support' }
}

# No per-node link. Each panel used to end with a way through to the services
# page, but that page is hidden for now, so the panels end on their description
# and the wheel itself is what the menu's Services entry points at. main.js
# hides the link when a node carries no data-href, so nothing else changes.
# Restoring it means emitting data-href and data-cta again, nothing more.

# The node artwork, drawn by the designer: white shapes with one accent colour.
# It lives in ring-icons.json rather than here because each icon carries its own
# viewBox and a few thousand characters of path data.
#
# One set covers both themes. The light and dark files supplied were identical
# apart from that accent -- #0249f7 against #85519b, which is exactly --gold in
# each theme -- so the accent is tagged .ico-a and coloured from the token in
# CSS. Shipping both sets would have meant fourteen files and a swap to get
# wrong; this way the theme already on the page decides it.
$ICONS = Get-Content (Join-Path $PSScriptRoot 'ring-icons.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# title doubles as the label under the badge; desc fills the detail panel
$STEPS = @(
  @{ icon = $ICONS.concept
     ka = @{ title = 'საინჟინრო კონცეფცია'
             desc  = 'ვგანსაზღვრავთ პროექტის ტექნიკურ მოთხოვნებს და ვაყალიბებთ საინჟინრო კონცეფციას' }
     en = @{ title = 'Engineering concept'
             desc  = 'We define the project''s technical requirements and shape the engineering concept' } },

  @{ icon = $ICONS.design
     ka = @{ title = 'პროექტირება'
             desc  = 'ვაპროექტებთ გათბობის, გაგრილების, ვენტილაციისა და წყალმომარაგების სისტემებს ობიექტის ტექნიკური მოთხოვნებისა და არქიტექტურულ-კონსტრუქციული პარამეტრების გათვლით' }
     en = @{ title = 'Design'
             desc  = 'We design the heating, cooling, ventilation and water-supply systems against the building''s technical requirements and its architectural and structural parameters' } },

  @{ icon = $ICONS.technology
     ka = @{ title = 'ტექნოლოგიების შერჩევა'
             desc  = 'ვარჩევთ პროექტის საინჟინრო გადაწყვეტასთან და ტექნიკურ მოთხოვნებთან შესაბამის წამყვანი საერთაშორისო მწარმოებლების ტექნოლოგიებს, მოწყობილობებსა და სისტემის კომპონენტებს' }
     en = @{ title = 'Technology selection'
             desc  = 'We select technologies, equipment and system components from leading international manufacturers to match the project''s engineering solution and technical requirements' } },

  @{ icon = $ICONS.logistics
     ka = @{ title = 'მიწოდება და ლოჯისტიკა'
             desc  = 'ვუზრუნველყოფთ პროექტისთვის განსაზღვრული მოწყობილობებისა და სისტემის კომპონენტების მიწოდებასა და ლოჯისტიკას' }
     en = @{ title = 'Supply and logistics'
             desc  = 'We handle the delivery and logistics of the equipment and system components specified for the project' } },

  @{ icon = $ICONS.installation
     ka = @{ title = 'მონტაჟი'
             desc  = 'ვახორციელებთ გათბობის, გაგრილების, ვენტილაციისა და წყალმომარაგების სისტემების მონტაჟს პროექტით განსაზღვრული ტექნიკური მოთხოვნების შესაბამისად' }
     en = @{ title = 'Installation'
             desc  = 'We install the heating, cooling, ventilation and water-supply systems in line with the technical requirements set by the design' } },

  @{ icon = $ICONS.commissioning
     ka = @{ title = 'გაშვება და გამართვა'
             desc  = 'ვახორციელებთ დამონტაჟებული სისტემების გაშვებასა და გამართვას პროექტით განსაზღვრული სამუშაო პარამეტრების შესაბამისად' }
     en = @{ title = 'Commissioning and set-up'
             desc  = 'We commission and set up the installed systems to the operating parameters defined by the design' } },

  @{ icon = $ICONS.service
     ka = @{ title = 'სერვისი და ტექნიკური მხარდაჭერა'
             desc  = 'ვუზრუნველყოფთ საინჟინრო სისტემების სერვისსა და ტექნიკურ მხარდაჭერას მათი ექსპლუატაციის განმავლობაში' }
     en = @{ title = 'Service and technical support'
             desc  = 'We provide service and technical support for the engineering systems throughout their working life' } }
)

# Which slot the cycle starts from, counted clockwise from twelve o'clock. Both
# the first node and the pointing hand land here, so the ring reads from the
# hand onwards -- the right-hand side, which is also where main.js brings a
# tapped node.
$START_SLOT = 2

function Esc($s) { $s -replace '&(?!(amp|lt|gt|quot|#\d+);)', '&amp;' -replace '"', '&quot;' }

foreach ($lang in 'ka', 'en') {
  $file = if ($lang -eq 'en') { 'index-en.html' } else { 'index.html' }
  $p = Join-Path $repo $file
  $s = [IO.File]::ReadAllText($p)

  # ---- heading and subtitle, inside the services section only
  $sec = $s.IndexOf('<section class="section section--dark" id="services">')
  if ($sec -lt 0) { throw "services section not found in $file" }
  $h2a = $s.IndexOf('<h2>', $sec); $h2b = $s.IndexOf('</h2>', $h2a)
  $s = $s.Substring(0, $h2a) + '<h2>' + $HEAD[$lang].h2 + $s.Substring($h2b)
  $pa = $s.IndexOf('<p>', $sec); $pb = $s.IndexOf('</p>', $pa)
  $s = $s.Substring(0, $pa) + '<p>' + $HEAD[$lang].p + $s.Substring($pb)

  # ---- the nodes: evenly spaced, however many there are
  #
  # The cycle begins under the pointing hand rather than at twelve o'clock. The
  # hand sits on the right-hand side, which is also where main.js brings a
  # tapped node, so the first step is already in the reading position when the
  # page loads and the rest follow it clockwise. $START_SLOT is the slot the
  # hand occupies, counted clockwise from the top; the modulo wraps the last
  # steps back around past twelve.
  #
  # $OFFSET turns the whole ring so that slot lands exactly on three o'clock.
  # Seven slots do not divide the circle into quarters -- slot 2 of 7 falls at
  # 102.86deg, a quarter of a step below the horizontal, which is near enough to
  # centred to look like a mistake rather than a decision. Every step keeps its
  # spacing; the first one just starts on the centre line, which is also the
  # line a tapped step is brought to, so the wheel opens where it already sits.
  $n = $STEPS.Count
  $OFFSET = 90.0 - 360.0 * $START_SLOT / $n
  $out = ''
  for ($i = 0; $i -lt $n; $i++) {
    $t = $STEPS[$i].$lang
    $a = [math]::Round(360.0 * (($i + $START_SLOT) % $n) / $n + $OFFSET, 2)
    $linkAttr = ''
    $out += '        <div class="ring__node" style="--a:' + $a + 'deg" data-title="' + (Esc $t.title) +
            '" data-desc="' + (Esc $t.desc) + '"' + $linkAttr + '>' + "`r`n" +
            '          <div class="node__badge">' + $STEPS[$i].icon + '</div>' + "`r`n" +
            '          <span class="node__label">' + $t.title + '</span>' + "`r`n" +
            '        </div>' + "`r`n"
  }

  $first  = $s.IndexOf('<div class="ring__node"')
  $detail = $s.IndexOf('<div class="ring__detail"')
  if ($first -lt 0 -or $detail -lt 0) { throw "ring markup not found in $file" }
  $close  = $s.LastIndexOf('</div>', $detail)   # the </div> that closes .ring
  # TrimEnd: the slice before $first ends with that line's own indent, and $out
  # brings its own, so without this each run left eight more spaces in front of
  # the first node than the last one did -- six runs today had it at 56.
  $s = $s.Substring(0, $first).TrimEnd(' ') + $out + '      ' + $s.Substring($close)

  # The tap hint sits on the slot the cycle starts from, worked out with the
  # same arithmetic and the same $OFFSET the nodes use rather than the fixed
  # 90deg it used to carry -- that was a node only while the ring had eight of
  # them. It comes back to 90 now that the ring is turned onto three o'clock,
  # but by construction rather than by coincidence: the hand and the first step
  # cannot drift apart if the step count changes.
  $ha = [math]::Round(360.0 * $START_SLOT / $n + $OFFSET, 2)
  $s = [regex]::Replace($s, '<div class="ring"(?:\s+style="[^"]*")?>',
                        ('<div class="ring" style="--hint-a:' + $ha + 'deg">'))

  # The detail panel carries the link that main.js fills in for the selected step
  # Rewritten here so it cannot drift between the two languages.
  $panel = '<div class="ring__detail" aria-live="polite">' + "`r`n" +
           '        <span class="ring__detail-tag"></span>' + "`r`n" +
           '        <h3 class="ring__detail-title"></h3>' + "`r`n" +
           '        <p class="ring__detail-desc"></p>' + "`r`n" +
           '        <a class="ring__detail-link" href="#" hidden></a>' + "`r`n" +
           '      </div>'
  $ds = $s.IndexOf('<div class="ring__detail"')
  $de = $s.IndexOf('</div>', $s.IndexOf('ring__detail-desc', $ds)) + 6
  $s = $s.Substring(0, $ds) + $panel + $s.Substring($de)

  # index.html is CRLF; keep it that way
  $s = [regex]::Replace($s, "`r`n|`n", "`r`n")
  [IO.File]::WriteAllText($p, $s, $BOM)
  Write-Host ("  $file : $n nodes, " + [math]::Round(360.0 / $n, 2) + ' deg apart')
}

# ---- the same seven steps on the about page
#
# "ALL IN ONE მოდელი" listed the cycle as plain bullets, which is the ring's
# content written out a second time by hand -- two places to edit and one of
# them certain to be forgotten. The list is generated from $STEPS now, wearing
# the ring's own artwork instead of a disc, so the two cannot say different
# things and a reader recognises the badges from the wheel.
#
# Each page holds exactly one <ul>, so that is the anchor.
foreach ($lang in 'ka', 'en') {
  $file = if ($lang -eq 'en') { 'about-en.html' } else { 'about.html' }
  $p = Join-Path $repo $file
  $s = [IO.File]::ReadAllText($p)

  $a = $s.IndexOf('<ul')
  $b = $s.IndexOf('</ul>', $a)
  if ($a -lt 0 -or $b -lt 0) { throw "cycle list not found in $file" }

  $ul = '<ul class="cycle">' + "`r`n"
  foreach ($step in $STEPS) {
    $ul += '          <li><span class="cycle__ico">' + $step.icon + '</span>' +
           $step.$lang.title + '</li>' + "`r`n"
  }
  $ul += '        '

  $s = $s.Substring(0, $a) + $ul + $s.Substring($b)
  $s = [regex]::Replace($s, "`r`n|`n", "`r`n")
  [IO.File]::WriteAllText($p, $s, $BOM)
  Write-Host ("  $file : " + $STEPS.Count + ' cycle steps with badges')
}
