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
  $n = $STEPS.Count
  $out = ''
  for ($i = 0; $i -lt $n; $i++) {
    $t = $STEPS[$i].$lang
    $a = [math]::Round(360.0 * $i / $n, 2)
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

  # The tap hint has to sit exactly on a node, so its angle comes from the same
  # arithmetic rather than the fixed 90deg it used to carry -- that was a node
  # only while the ring had eight of them, and 90 is not a multiple of 360/7.
  # HINT_ON picks which node it points at; the third sits on the right-hand
  # side, roughly where the hint has always appeared.
  $HINT_ON = 2
  $ha = [math]::Round(360.0 * $HINT_ON / $n, 2)
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
