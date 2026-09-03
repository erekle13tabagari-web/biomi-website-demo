# The service and technical support page.
#
# The last step of the ALL IN ONE cycle is the one a customer comes back to
# after the project is finished, so it gets a page of its own rather than a
# sentence in a ring tooltip. tools/ring.ps1 links the ring node here.
#
# Chrome (header, footer, drawer) is spliced off about.html the same way
# tools/legal.ps1 builds the privacy page: the pages live at the repo root, so
# every relative path in that chrome is already correct.
$repo  = Split-Path $PSScriptRoot -Parent
$NOBOM = New-Object Text.UTF8Encoding($false)

$L = @{
  ka = @{
    sfx = '.html'; home = 'მთავარი'; eyebrow = 'სერვისი'
    crumb = 'სერვისი და ტექნიკური მხარდაჭერა'
    title = 'სერვისი და ტექნიკური მხარდაჭერა - ბიომი'
    desc  = 'საინჟინრო სისტემების ტექნიკური მომსახურება, დიაგნოსტიკა და პრევენციული სერვისი - ბიომი ჰოლდინგი.'
    h1    = 'სერვისი და ტექნიკური მხარდაჭერა'
    lead  = 'საინჟინრო სისტემების ტექნიკური მომსახურება, დიაგნოსტიკა და პრევენციული სერვისი.'
    h2a   = 'ტექნიკური მომსახურება მოიცავს'
    items = @(
      'ჰაერის ფილტრებისა და სითბოგადამცვლელების შემოწმებას, გაწმენდასა და საჭიროების შემთხვევაში შეცვლას',
      'ვენტილატორების, კომპრესორებისა და ძრავების ტექნიკურ შემოწმებას',
      'გათბობისა და გაგრილების სისტემების სამუშაო პარამეტრების - წნევის, ტემპერატურისა და ცირკულაციის - შემოწმებას',
      'ვენტილაციის სისტემებში ჰაერის ნაკადის შემოწმებას, ბალანსირებასა და გამართვას',
      'სისტემების სეზონურ შემოწმებასა და გამართვას',
      'შესაბამისი სისტემების შემთხვევაში, CO&#8322;-ის, ტენიანობისა და ჰაერის ხარისხის სენსორების შემოწმებასა და გამართვას',
      'ტექნიკური ხარვეზების დიაგნოსტიკასა და აღმოფხვრას.'
    )
    h2b   = 'პრევენციული და სეზონური სერვისი'
    pb1   = 'ვახორციელებთ სისტემების გეგმურ ტექნიკურ შემოწმებასა და სეზონურ მომსახურებას მათი ექსპლუატაციის მოთხოვნების შესაბამისად.'
    pb2   = 'რეგულარული ტექნიკური მომსახურება ხელს უწყობს სისტემის გამართული მუშაობის შენარჩუნებას, გაუთვალისწინებელი შეფერხებების რისკის შემცირებასა და მოწყობილობების ხანგრძლივ ექსპლუატაციას.'
    h2c   = 'დაგეგმეთ ტექნიკური სერვისი'
    ask   = 'გჭირდებათ სისტემის ტექნიკური შეფასება ან გეგმური მომსახურება?'
    cta   = 'სერვისის დაგეგმვა'
    back  = 'ALL IN ONE ციკლი'
  }
  en = @{
    sfx = '-en.html'; home = 'Home'; eyebrow = 'Service'
    crumb = 'Service and technical support'
    title = 'Service and technical support - Biomi'
    desc  = 'Technical maintenance, diagnostics and preventive service for engineering systems - Biomi Holding.'
    h1    = 'Service and technical support'
    lead  = 'Technical maintenance, diagnostics and preventive service for engineering systems.'
    h2a   = 'What technical maintenance covers'
    items = @(
      'Inspection, cleaning and, where needed, replacement of air filters and heat exchangers',
      'Technical inspection of fans, compressors and motors',
      'Checking the operating parameters of the heating and cooling systems - pressure, temperature and circulation',
      'Checking, balancing and adjusting the airflow in ventilation systems',
      'Seasonal inspection and set-up of the systems',
      'Where the systems have them, checking and calibrating the CO&#8322;, humidity and air-quality sensors',
      'Diagnosing and resolving technical faults.'
    )
    h2b   = 'Preventive and seasonal service'
    pb1   = 'We carry out scheduled technical inspections and seasonal servicing in line with the operating requirements of the systems.'
    pb2   = 'Regular maintenance helps keep a system working as it should, reduces the risk of unplanned interruptions and extends the working life of the equipment.'
    h2c   = 'Schedule a technical service'
    ask   = 'Do you need a technical assessment of your system, or scheduled maintenance?'
    cta   = 'Schedule a service'
    back  = 'The ALL IN ONE cycle'
  }
}

foreach ($lang in 'ka', 'en') {
  $t   = $L[$lang]
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('about' + $t.sfx)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in about' + $t.sfx) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)
  # the meta block belongs to tools/build-meta.ps1
  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
  $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"',
                           ('<meta name="description" content="' + $t.desc + '"'))
  # The chrome still carries About's own language switch -- one copy in the
  # header ($head) and one in the drawer ($tail). Matching on the GEO/ENG labels
  # leaves the nav's link to the About page alone.
  foreach ($pair in @(@('href="about.html">GEO<', 'href="service.html">GEO<'),
                      @('href="about-en.html">ENG<', 'href="service-en.html">ENG<'))) {
    $head = $head.Replace($pair[0], $pair[1])
    $tail = $tail.Replace($pair[0], $pair[1])
  }

  $li = ''
  foreach ($it in $t.items) { $li += '          <li>' + $it + '</li>' + "`r`n" }

  $body = @'
<section class="page-hero">
  <div class="container">
    <article class="article">
      <nav class="crumbs" aria-label="breadcrumb">
        <a href="index{SFX}">{HOME}</a><span class="sep">/</span>
        <b>{CRUMB}</b>
      </nav>

      <span class="eyebrow">{EYEBROW}</span>
      <h1>{H1}</h1>
      <p class="article__lead">{LEAD}</p>

      <div class="article__body">
        <h2>{H2A}</h2>
        <ul>
{LI}        </ul>

        <h2>{H2B}</h2>
        <p>{PB1}</p>
        <p>{PB2}</p>

        <h2>{H2C}</h2>
        <p>{ASK}</p>
      </div>

      <div class="article__foot">
        <a class="btn btn--gold" href="index{SFX}#contact">{CTA}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a>
        <a class="btn btn--outline" href="index{SFX}#services">{BACK}</a>
      </div>
    </article>
  </div>
</section>

'@
  $body = $body.Replace('{SFX}', $t.sfx).Replace('{HOME}', $t.home).Replace('{CRUMB}', $t.crumb).
                Replace('{EYEBROW}', $t.eyebrow).Replace('{H1}', $t.h1).Replace('{LEAD}', $t.lead).
                Replace('{H2A}', $t.h2a).Replace('{LI}', $li).
                Replace('{H2B}', $t.h2b).Replace('{PB1}', $t.pb1).Replace('{PB2}', $t.pb2).
                Replace('{H2C}', $t.h2c).Replace('{ASK}', $t.ask).
                Replace('{CTA}', $t.cta).Replace('{BACK}', $t.back)

  $out = Join-Path $repo ('service' + $t.sfx)
  [IO.File]::WriteAllText($out, ($head + $body + $tail), $NOBOM)
  Write-Host ('  wrote service' + $t.sfx)
}
