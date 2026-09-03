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

# icon = the SVG body, carried over from the markup this replaces
$BULB  = '<path d="M9 18h6M10 21h4"/><path d="M12 2a7 7 0 0 0-4 12.6c.6.5 1 1.3 1 2.1v.3h6v-.3c0-.8.4-1.6 1-2.1A7 7 0 0 0 12 2Z"/>'
$DRAFT = '<circle cx="12" cy="5" r="2"/><path d="M12 7v3M8.5 21 12 11l3.5 10M10 17h4"/>'
$NODES = '<path d="M4 6h8M16 6h4M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="14" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>'
$TRUCK = '<path d="M2 7h12v9H2zM14 10h4l3 3v3h-7z"/><circle cx="7" cy="18" r="1.8"/><circle cx="17" cy="18" r="1.8"/>'
$WRENCH= '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4l-2.7 2.7-2.3-.6-.6-2.3 2.6-2.2z"/>'
$GAUGE = '<path d="M4 15a8 8 0 0 1 16 0"/><path d="M12 15l4-4"/><path d="M3 19h18"/>'
$HEADSET= '<path d="M4 13v-1a8 8 0 0 1 16 0v1"/><path d="M5 13a2 2 0 0 1 2 2v2a2 2 0 0 1-4 0v-2a2 2 0 0 1 2-2ZM19 13a2 2 0 0 0-2 2v2a2 2 0 0 0 4 0v-2a2 2 0 0 0-2-2Z"/><path d="M19 18a4 4 0 0 1-4 3.5h-3"/>'

# label is the short word under the badge; title and desc fill the detail panel
$STEPS = @(
  @{ icon = $BULB
     ka = @{ label = 'კონცეფცია';    title = 'საინჟინრო კონცეფცია'
             desc  = 'ვგანსაზღვრავთ პროექტის ტექნიკურ მოთხოვნებს და ვაყალიბებთ საინჟინრო კონცეფციას' }
     en = @{ label = 'Concept';      title = 'Engineering concept'
             desc  = 'We define the project''s technical requirements and shape the engineering concept' } },

  @{ icon = $DRAFT
     ka = @{ label = 'პროექტირება';  title = 'პროექტირება'
             desc  = 'ვაპროექტებთ გათბობის, გაგრილების, ვენტილაციისა და წყალმომარაგების სისტემებს ობიექტის ტექნიკური მოთხოვნებისა და არქიტექტურულ-კონსტრუქციული პარამეტრების გათვლით' }
     en = @{ label = 'Design';       title = 'Design'
             desc  = 'We design the heating, cooling, ventilation and water-supply systems against the building''s technical requirements and its architectural and structural parameters' } },

  @{ icon = $NODES
     ka = @{ label = 'ტექნოლოგია';   title = 'ტექნოლოგიების შერჩევა'
             desc  = 'ვარჩევთ პროექტის საინჟინრო გადაწყვეტასთან და ტექნიკურ მოთხოვნებთან შესაბამის წამყვანი საერთაშორისო მწარმოებლების ტექნოლოგიებს, მოწყობილობებსა და სისტემის კომპონენტებს' }
     en = @{ label = 'Technology';   title = 'Technology selection'
             desc  = 'We select technologies, equipment and system components from leading international manufacturers to match the project''s engineering solution and technical requirements' } },

  @{ icon = $TRUCK
     ka = @{ label = 'ლოჯისტიკა';    title = 'მიწოდება და ლოჯისტიკა'
             desc  = 'ვუზრუნველყოფთ პროექტისთვის განსაზღვრული მოწყობილობებისა და სისტემის კომპონენტების მიწოდებასა და ლოჯისტიკას' }
     en = @{ label = 'Logistics';    title = 'Supply and logistics'
             desc  = 'We handle the delivery and logistics of the equipment and system components specified for the project' } },

  @{ icon = $WRENCH
     ka = @{ label = 'მონტაჟი';      title = 'მონტაჟი'
             desc  = 'ვახორციელებთ გათბობის, გაგრილების, ვენტილაციისა და წყალმომარაგების სისტემების მონტაჟს პროექტით განსაზღვრული ტექნიკური მოთხოვნების შესაბამისად' }
     en = @{ label = 'Installation'; title = 'Installation'
             desc  = 'We install the heating, cooling, ventilation and water-supply systems in line with the technical requirements set by the design' } },

  @{ icon = $GAUGE
     ka = @{ label = 'გამართვა';     title = 'გაშვება და გამართვა'
             desc  = 'ვახორციელებთ დამონტაჟებული სისტემების გაშვებასა და გამართვას პროექტით განსაზღვრული სამუშაო პარამეტრების შესაბამისად' }
     en = @{ label = 'Set-up';       title = 'Commissioning and set-up'
             desc  = 'We commission and set up the installed systems to the operating parameters defined by the design' } },

  # The only step with a page of its own: it is the one a customer comes back to
  # once the project is finished, so the detail panel offers a way through to it.
  @{ icon = $HEADSET
     ka = @{ label = 'სერვისი';      title = 'სერვისი და ტექნიკური მხარდაჭერა'
             desc  = 'ვუზრუნველყოფთ საინჟინრო სისტემების სერვისსა და ტექნიკურ მხარდაჭერას მათი ექსპლუატაციის განმავლობაში'
             href  = 'service.html';    cta = 'ვრცლად სერვისის შესახებ' }
     en = @{ label = 'Service';      title = 'Service and technical support'
             desc  = 'We provide service and technical support for the engineering systems throughout their working life'
             href  = 'service-en.html'; cta = 'More about service' } }
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
    $link = ''
    if ($t.href) { $link = ' data-href="' + $t.href + '" data-cta="' + (Esc $t.cta) + '"' }
    $out += '        <div class="ring__node" style="--a:' + $a + 'deg" data-title="' + (Esc $t.title) +
            '" data-desc="' + (Esc $t.desc) + '"' + $link + '>' + "`r`n" +
            '          <div class="node__badge"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7">' +
            $STEPS[$i].icon + '</svg></div>' + "`r`n" +
            '          <span class="node__label">' + $t.label + '</span>' + "`r`n" +
            '        </div>' + "`r`n"
  }

  $first  = $s.IndexOf('<div class="ring__node"')
  $detail = $s.IndexOf('<div class="ring__detail"')
  if ($first -lt 0 -or $detail -lt 0) { throw "ring markup not found in $file" }
  $close  = $s.LastIndexOf('</div>', $detail)   # the </div> that closes .ring
  $s = $s.Substring(0, $first) + $out + '      ' + $s.Substring($close)

  # The tap hint has to sit exactly on a node, so its angle comes from the same
  # arithmetic rather than the fixed 90deg it used to carry -- that was a node
  # only while the ring had eight of them, and 90 is not a multiple of 360/7.
  # HINT_ON picks which node it points at; the third sits on the right-hand
  # side, roughly where the hint has always appeared.
  $HINT_ON = 2
  $ha = [math]::Round(360.0 * $HINT_ON / $n, 2)
  $s = [regex]::Replace($s, '<div class="ring"(?:\s+style="[^"]*")?>',
                        ('<div class="ring" style="--hint-a:' + $ha + 'deg">'))

  # The detail panel carries a link that main.js fills in for whichever step has
  # a page. Rewritten here so it cannot drift between the two languages.
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
