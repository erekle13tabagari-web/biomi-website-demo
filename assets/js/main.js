/* ბიომი - interactions */
(function () {
  'use strict';

  /* ---- Form delivery: one place for both the contact form and the call-back
     panel.

     Contact form -> api/contact.php on our own server (ProService). It emails
     the office (the address is set on the server, in biomi-config.php) and logs
     the request and the privacy/marketing consents. The path is worked out from
     where this file was loaded, so pages in products/ find it too.

     Call-back panel -> Citynet, the office phone system, which rings the visitor
     back. Citynet knows the site as https://biomi.ge and only hands its key out
     for that name, so every copy of the site (test.biomi.ge too) introduces
     itself as biomi.ge.

     Both only run on biomi.ge and its subdomains. Anywhere else - the GitHub
     Pages demo, a page opened from disk - they refuse and say so, rather than
     ring a real customer's phone from a demo or post to a server that is not
     there. Answering "received" while sending nothing is worse than an error:
     a customer would walk away believing they had been in touch. */
  var FORMS = {
    LIVE:         /(^|\.)biomi\.ge$/i.test(location.hostname),
    ENDPOINT:     new URL('../../api/contact.php',
                    (document.currentScript && document.currentScript.src) || location.href).href,
    CITYNET:      'https://api.portal.citynet.ge/request_call_widget/v1/',
    CITYNET_SITE: 'https://biomi.ge',
    TEL:          '+995322151115'
  };

  /* ---- Georgian caps (Mtavruli) wherever CSS asks for uppercase ---- */
  /* CSS text-transform:uppercase handles Latin but does nothing for Georgian, so
     Mkhedruli text nodes are converted to Mtavruli (U+10D0-U+10FF -> +0xBC0).
     Rather than keep a hand-written selector list in sync with the stylesheet,
     this reads the computed style: anything CSS renders uppercase (headings,
     .eyebrow kickers, .news__cat chips, nav links, tags) gets Georgian caps too.
     Style a new element uppercase in CSS and it is covered automatically.
     aria-label keeps the readable Mkhedruli text for screen readers. The regex
     matches only Mkhedruli, so already-Mtavruli source and re-runs are no-ops. */
  var georgianCaps = (function () {
    // Mkhedruli (lowercase) OR Mtavruli (caps) -- some titles are authored in
    // Mtavruli already, and those still need the CSS transform switched off.
    var GEORGIAN = /[ა-ჿᲐ-Ჿ]/;
    function isUpper(el) {
      return el && el.nodeType === 1 && getComputedStyle(el).textTransform === 'uppercase';
    }
    /* Returned rather than run once and forgotten: anything assembled later in
       JS -- the call-back panel below is built after this first pass -- has to
       go through the same conversion. Skip it and that markup renders exactly
       as CSS leaves it, which for Georgian means visibly un-capitalised while
       the English beside it is in caps. */
    return function (root) {
      (root || document).querySelectorAll('*').forEach(function (el) {
        if (!isUpper(el)) return;
        // text-transform inherits, so let the outermost uppercase element handle
        // its subtree in one pass instead of converting each descendant again.
        if (isUpper(el.parentElement)) return;
        if (el.dataset.caps) return;

        var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
        var nodes = [], n;
        while ((n = walker.nextNode())) nodes.push(n);
        // Latin-only elements are left to CSS, so caps still work with JS disabled.
        if (!nodes.some(function (t) { return GEORGIAN.test(t.nodeValue); })) return;

        el.dataset.caps = '1';
        if (!el.getAttribute('aria-label')) el.setAttribute('aria-label', el.textContent.trim());
        // toUpperCase does the Unicode mapping for both scripts: Mkhedruli -> Mtavruli
        // and Latin -> caps, leaving text that is already Mtavruli untouched.
        nodes.forEach(function (t) { t.nodeValue = t.nodeValue.toUpperCase(); });
        // Critical: CSS text-transform:uppercase maps Mtavruli *back down* to
        // Mkhedruli, silently undoing the conversion. Now that this element's text
        // is already cased, switch the CSS transform off so it cannot reverse it.
        el.style.textTransform = 'none';
      });
    };
  })();
  georgianCaps(document);

  /* ---- Analytics: Google Analytics 4, behind a consent bar ----
     Nothing from Google loads until the visitor says yes: privacy.html promises
     consent before cookies, and GA sets cookies and sends data to Google. The
     answer is remembered in this browser for a year (localStorage - keeping a
     "no" is the one thing that must be stored without asking), and a "Cookie
     settings" link added to every footer brings the bar back to change it.

     GA_ID is the Measurement ID (G-...) of Biomi's own GA property. Empty means
     off, and on biomi.ge the bar does not appear at all until it is set.
     test.biomi.ge always shows the bar so it can be checked, but sends data only
     in a tab opened once with ?gadebug - and then in debug mode, which GA's
     "Developer traffic" filter keeps out of the real reports.

     track(name, params) records an event; before consent it does nothing. */
  var ANALYTICS = {
    GA_ID:   'G-F0J6WZ8NRQ',   // Biomi's GA4 property "biomi.ge" (created 2026-09-18)
    VERSION: 1,      // raise to ask everyone again, e.g. when a new tracker is added
    DAYS:    365
  };
  var track = (function () {
    var host = location.hostname.toLowerCase(),
        isTest = /^test\./.test(host),
        en = (document.documentElement.lang || 'ka').indexOf('en') === 0,
        root = new URL('../../', (document.currentScript && document.currentScript.src) || location.href).href,
        KEY = 'biomi-consent',
        loaded = false;

    var debugOn = false;
    try {
      if (/[?&]gadebug\b/.test(location.search)) sessionStorage.setItem('biomi-gadebug', '1');
      debugOn = isTest && sessionStorage.getItem('biomi-gadebug') === '1';
    } catch (e) {}
    var canSend = FORMS.LIVE && !!ANALYTICS.GA_ID && (!isTest || debugOn),
        offered = FORMS.LIVE && (!!ANALYTICS.GA_ID || isTest);

    function read() {
      try {
        var c = JSON.parse(localStorage.getItem(KEY) || 'null');
        if (!c || c.v !== ANALYTICS.VERSION || Date.now() - c.at > ANALYTICS.DAYS * 864e5) return null;
        return c;
      } catch (e) { return null; }
    }
    function save(yes) {
      try { localStorage.setItem(KEY, JSON.stringify({ v: ANALYTICS.VERSION, analytics: yes, at: Date.now() })); } catch (e) {}
    }

    function load() {
      if (!canSend) return;
      window['ga-disable-' + ANALYTICS.GA_ID] = false;
      if (loaded) return;
      loaded = true;
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { window.dataLayer.push(arguments); };
      // analytics only: nothing about ads is ever switched on
      window.gtag('consent', 'default', { analytics_storage: 'granted', ad_storage: 'denied',
                                          ad_user_data: 'denied', ad_personalization: 'denied' });
      window.gtag('js', new Date());
      window.gtag('config', ANALYTICS.GA_ID, debugOn ? { debug_mode: true } : {});
      var s = document.createElement('script');
      s.async = true;
      s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(ANALYTICS.GA_ID);
      document.head.appendChild(s);
    }
    // A "no" after a "yes": GA stops sending at once and its cookies are cleared.
    function unload() {
      if (ANALYTICS.GA_ID) window['ga-disable-' + ANALYTICS.GA_ID] = true;
      var base = host.split('.').slice(-2).join('.');
      document.cookie.split(';').forEach(function (c) {
        var name = c.split('=')[0].trim();
        if (!/^_ga/.test(name)) return;
        ['', host, '.' + base].forEach(function (d) {
          document.cookie = name + '=; Max-Age=0; path=/' + (d ? '; domain=' + d : '');
        });
      });
    }

    function track(name, params) {
      if (loaded && window.gtag && !window['ga-disable-' + ANALYTICS.GA_ID]) window.gtag('event', name, params || {});
    }

    /* Every Accept or Decline is also written to the consent log on our server
       (api/consent.php), so Biomi can show a given visitor's choice and see how
       many accept. The visitor is known only by a random ID this browser keeps;
       it survives a VERSION bump, so a re-ask adds a row to the same visitor. */
    function consentId() {
      var id = '';
      try { id = localStorage.getItem('biomi-consent-id') || ''; } catch (e) {}
      if (!/^[a-f0-9]{32}$/.test(id)) {
        var bytes = new Uint8Array(16);
        (window.crypto || window.msCrypto).getRandomValues(bytes);
        id = Array.prototype.map.call(bytes, function (b) { return (b < 16 ? '0' : '') + b.toString(16); }).join('');
        try { localStorage.setItem('biomi-consent-id', id); } catch (e) {}
      }
      return id;
    }
    function logChoice(yes) {
      try {
        var fd = new FormData();
        fd.append('choice', yes ? 'accept' : 'decline');
        fd.append('id', consentId());
        fd.append('version', ANALYTICS.VERSION);
        fd.append('lang', en ? 'en' : 'ka');
        fd.append('page', location.pathname);
        // keepalive: the visitor may click a link straight after answering
        fetch(root + 'api/consent.php', { method: 'POST', body: fd, keepalive: true })
          .catch(function () {});
      } catch (e) {}
    }

    if (!offered) return track;

    var T = en ? {
      title: 'Cookies',
      policy: 'Privacy policy', href: 'privacy-en.html',
      yes: 'Accept', no: 'Decline', settings: 'Cookie settings'
    } : {
      title: 'ქუქი-ფაილები',
      policy: 'კონფიდენციალურობის პოლიტიკა', href: 'privacy.html',
      yes: 'მიღება', no: 'უარყოფა', settings: 'ქუქი-ფაილების პარამეტრები'
    };
    var COOKIE_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">' +
      '<path d="M21 12.3A9 9 0 1 1 11.7 3a3.5 3.5 0 0 0 4.6 4.1 3.5 3.5 0 0 0 4.7 5.2Z"/>' +
      '<circle cx="8.5" cy="10.5" r="1" fill="currentColor"/><circle cx="13" cy="15.5" r="1" fill="currentColor"/>' +
      '<circle cx="8" cy="15.5" r=".8" fill="currentColor"/></svg>';

    var bar = null;
    function openBar() {
      if (!bar) {
        bar = document.createElement('div');
        bar.className = 'cookiebar';
        bar.setAttribute('role', 'region');
        bar.setAttribute('aria-labelledby', 'cookiebarTitle');
        bar.innerHTML =
          '<span class="cookiebar__icon">' + COOKIE_SVG + '</span>' +
          '<div class="cookiebar__text">' +
            '<h3 id="cookiebarTitle">' + T.title + '</h3>' +
            // no explanation line (the user asked for it gone, 2026-09-15): the
            // policy link is where a visitor reads what Google Analytics does
            '<p><a href="' + root + T.href + '">' + T.policy + '</a></p>' +
          '</div>' +
          '<div class="cookiebar__actions">' +
            '<button class="btn btn--primary" type="button" data-consent="yes">' + T.yes + '</button>' +
            '<button class="btn btn--outline" type="button" data-consent="no">' + T.no + '</button>' +
          '</div>';
        document.body.appendChild(bar);
        georgianCaps(bar);
        bar.addEventListener('click', function (e) {
          var b = e.target.closest('[data-consent]');
          if (!b) return;
          var yes = b.getAttribute('data-consent') === 'yes';
          save(yes);
          logChoice(yes);
          if (yes) load(); else unload();
          if (window.console && isTest) console.info('analytics consent:', yes ? 'yes' : 'no',
            canSend ? '(sending)' : '(not sending: ' + (ANALYTICS.GA_ID ? 'open with ?gadebug to test' : 'no GA_ID yet') + ')');
          bar.classList.remove('is-open');
        });
      }
      requestAnimationFrame(function () { requestAnimationFrame(function () { bar.classList.add('is-open'); }); });
    }

    // "Cookie settings" under the two policy links in every footer
    document.querySelectorAll('.footer__policies').forEach(function (box) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'footer__policy footer__policy--btn';
      b.innerHTML = COOKIE_SVG + T.settings;
      b.addEventListener('click', openBar);
      box.appendChild(b);
    });

    // phone, email and Messenger clicks, wherever they are on the page
    document.addEventListener('click', function (e) {
      var a = e.target.closest && e.target.closest('a[href]');
      if (!a || a.classList.contains('fab__ph')) return;   // the phone button opens the call-back panel
      var h = a.getAttribute('href');
      if (/^tel:/i.test(h)) track('click_phone', { link_url: h });
      else if (/^mailto:/i.test(h)) track('click_email', { link_url: h });
      else if (/(^|\/\/)m\.me\//i.test(h)) track('click_messenger', { link_url: h });
    }, true);

    var choice = read();
    if (choice && choice.analytics) load();
    if (!choice) setTimeout(openBar, 900);
    return track;
  })();

  /* ---- Floating buttons: group socials into one capsule; order below it:
         messenger, phone (call CTA), back-to-top ---- */
  (function () {
    var fab = document.querySelector('.fab');
    if (!fab) return;
    var li = fab.querySelector('.fab__li'),
        ig = fab.querySelector('.fab__ig'),
        yt = fab.querySelector('.fab__yt'),
        ms = fab.querySelector('.fab__ms'),
        ph = fab.querySelector('.fab__ph'),
        top = fab.querySelector('.fab__top');
    if (li && ig && yt) {
      var cap = document.createElement('div');
      cap.className = 'fab__social';
      cap.appendChild(li);   // LinkedIn
      var fb = document.createElement('a');   // Facebook (after LinkedIn)
      fb.className = 'fab__fb';
      fb.href = 'https://www.facebook.com/p/Biomi-Holding-ბიომი-ჰოლდინგი-61579642613208/';
      fb.target = '_blank';
      fb.rel = 'noopener';
      fb.setAttribute('aria-label', 'Facebook');
      fb.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.3c-1.2 0-1.6.8-1.6 1.6V12h2.8l-.5 2.9h-2.3v7A10 10 0 0 0 22 12Z"/></svg>';
      cap.appendChild(fb);   // Facebook
      cap.appendChild(ig);   // Instagram
      cap.appendChild(yt);   // YouTube
      fab.insertBefore(cap, fab.firstChild);
      // hide the social capsule once the footer scrolls into view
      var footer = document.querySelector('.footer');
      if (footer && 'IntersectionObserver' in window) {
        new IntersectionObserver(function (entries) {
          cap.classList.toggle('is-hidden', entries[0].isIntersecting);
        }, { threshold: 0 }).observe(footer);
      }
    }
    if (ms) fab.appendChild(ms);   // Messenger (blue, like the call button)
    if (ph) fab.appendChild(ph);   // Phone - call CTA
    if (top) fab.appendChild(top); // Back to top
  })();

  /* ---- Call-back request ------------------------------------------------
     The phone button used to be a bare tel: link, which does nothing at all in
     a desktop browser -- roughly half the visitors got a dead button. It now
     opens a panel where a visitor leaves a number and picks when to be called,
     with the direct-dial link kept inside for anyone who would rather call.

     Built here rather than in markup so all 185 pages get it without being
     edited one by one, the same reason the social capsule above is assembled
     in JS. Requests go to Citynet (see FORMS at the top of the file), the same
     service the old site's orange widget used - one call-back, not two.

     Citynet's flow: get_api_key (for the site name) -> get_schedule (the office
     hours set in the Citynet portal) -> request_call (phone + time). A first
     request from a number may answer "otp sent": Citynet texts a code, and the
     same request is sent again with it. */
  (function () {
    var fabPh = document.querySelector('.fab__ph');
    if (!fabPh) return;

    /* The office hours come from Citynet, so changing them in the Citynet portal
       changes the picker. DEFAULT_HOURS is only what shows before that answer
       arrives, or on a copy of the site that does not talk to Citynet. Keys are
       Citynet's weekday ids, 1 = Monday ... 7 = Sunday. STEP is the gap between
       slots (Citynet's own widget uses 15); LEAD is how far ahead the first
       booked slot today has to be - "now" covers anyone in more of a hurry. */
    var STEP_MIN  = 15,
        LEAD_MIN  = 60,
        DAYS_AHEAD = 5,
        DEFAULT_HOURS = {};
    [1, 2, 3, 4, 5].forEach(function (id) {
      DEFAULT_HOURS[id] = { work_start: '10:00:00', work_end: '18:00:00', break_start: null, break_end: null };
    });
    var hours = DEFAULT_HOURS;

    var en = (document.documentElement.lang || 'ka').indexOf('en') === 0;
    var T = en ? {
      title: 'Shall we call you?',
      sub:   'Leave your number and pick a time - we will call you then.',
      phone: 'Phone number', day: 'Day', time: 'Time',
      send:  'Request a call', now: 'or call us now', close: 'Close',
      today: 'Today', tomorrow: 'Tomorrow',
      bad:   'Please enter a 9-digit Georgian mobile number, starting with 5.',
      sending: 'Sending…',
      ok:    'Thank you. We will call you {d} at {t}.',
      fail:  'The request could not be sent. Please call +995 322 15 11 15.',
      unwired: 'The form is not connected yet. Please call +995 322 15 11 15.',
      nowOpt: 'Now',
      okNow: 'Thank you. A manager will call you within a minute.',
      otpSub: 'We sent an SMS code to +995 {p}. Enter it to confirm the call request.',
      otpLabel: 'SMS code', confirm: 'Confirm',
      otpNeed: 'Please enter the SMS code.',
      otpBad: 'That SMS code is not right. Please try again.',
      passed: 'That time has already passed - please pick another.',
      closed: 'Call-back requests are not available right now. Please call +995 322 15 11 15.',
      months: ['January','February','March','April','May','June','July',
               'August','September','October','November','December'],
      wdays:  ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'],
      mo:     ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
      wd:     ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
    } : {
      title: 'გსურთ, ჩვენ დაგირეკოთ?',
      sub:   'დატოვეთ ნომერი და აირჩიეთ დრო - დაგირეკავთ მითითებულ დროს.',
      phone: 'ტელეფონის ნომერი', day: 'დღე', time: 'დრო',
      send:  'ველოდები ზარს', now: 'ან დაგვირეკეთ ახლავე', close: 'დახურვა',
      today: 'დღეს', tomorrow: 'ხვალ',
      bad:   'მიუთითეთ 9-ნიშნა ნომერი, 5-ით დაწყებული.',
      sending: 'იგზავნება…',
      ok:    'მადლობა! დაგირეკავთ {d}, {t} საათზე.',
      fail:  'მოთხოვნა ვერ გაიგზავნა. დაგვირეკეთ +995 322 15 11 15.',
      unwired: 'ფორმა ჯერ არ არის დაკავშირებული. დაგვირეკეთ +995 322 15 11 15.',
      nowOpt: 'ახლავე',
      okNow: 'მადლობა! მენეჯერი დაგირეკავთ 1 წუთის განმავლობაში.',
      otpSub: 'SMS კოდი გაიგზავნა ნომერზე +995 {p}. შეიყვანეთ კოდი ზარის მოთხოვნის დასადასტურებლად.',
      otpLabel: 'SMS კოდი', confirm: 'დადასტურება',
      otpNeed: 'შეიყვანეთ SMS კოდი.',
      otpBad: 'SMS კოდი არასწორია. სცადეთ ხელახლა.',
      passed: 'ეს დრო უკვე გავიდა - აირჩიეთ სხვა დრო.',
      closed: 'ზარის მოთხოვნა ახლა მიუწვდომელია. დაგვირეკეთ +995 322 15 11 15.',
      months: ['იანვარი','თებერვალი','მარტი','აპრილი','მაისი','ივნისი','ივლისი',
               'აგვისტო','სექტემბერი','ოქტომბერი','ნოემბერი','დეკემბერი'],
      wdays:  ['კვირა','ორშაბათი','სამშაბათი','ოთხშაბათი','ხუთშაბათი','პარასკევი','შაბათი'],
      mo:     ['იან','თებ','მარ','აპრ','მაი','ივნ','ივლ','აგვ','სექ','ოქტ','ნოე','დეკ'],
      wd:     ['კვი','ორშ','სამ','ოთხ','ხუთ','პარ','შაბ']
    };

    /* Georgian flag, drawn rather than an emoji: Windows renders the regional
       indicator pair as the letters "GE", not a flag. */
    var FLAG =
      '<svg class="cbk__flag" viewBox="0 0 30 20" aria-hidden="true">' +
      '<rect width="30" height="20" fill="#fff"/>' +
      '<rect x="12.5" width="5" height="20" fill="#e8112d"/>' +
      '<rect y="7.5" width="30" height="5" fill="#e8112d"/><g fill="#e8112d">' +
      '<rect x="5.65" y="2.15" width="1.2" height="3.2"/><rect x="4.65" y="3.15" width="3.2" height="1.2"/>' +
      '<rect x="23.15" y="2.15" width="1.2" height="3.2"/><rect x="22.15" y="3.15" width="3.2" height="1.2"/>' +
      '<rect x="5.65" y="14.65" width="1.2" height="3.2"/><rect x="4.65" y="15.65" width="3.2" height="1.2"/>' +
      '<rect x="23.15" y="14.65" width="1.2" height="3.2"/><rect x="22.15" y="15.65" width="3.2" height="1.2"/>' +
      '</g></svg>';

    function sameDay(a, b) {
      return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() &&
             a.getDate() === b.getDate();
    }
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function hm(s) { var p = String(s || '').split(':'); return (+p[0] || 0) * 60 + (+p[1] || 0); }

    /* The office is in Tbilisi and Citynet reads every time as Tbilisi time, so
       the picker works on the Tbilisi clock whatever the visitor's own is set
       to. Georgia has no summer time: always UTC+4. The Date returned carries
       Tbilisi's wall-clock time in its local fields. */
    function tbNow() {
      var d = new Date();
      return new Date(d.getTime() + (d.getTimezoneOffset() + 240) * 60000);
    }
    function stamp(d) {
      return iso(d) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
    }
    function dayHours(d) { return hours[d.getDay() || 7] || null; }   // JS Sunday is 0, Citynet's is 7

    // Inside today's hours and not on a break: a call can be asked for right now.
    function canCallNow() {
      var now = tbNow(), h = dayHours(now);
      if (!h) return false;
      var m = now.getHours() * 60 + now.getMinutes();
      if (m < hm(h.work_start) || m >= hm(h.work_end)) return false;
      return !(h.break_start && h.break_end && m >= hm(h.break_start) && m <= hm(h.break_end));
    }

    /* Slots left on a given day, the way Citynet's own widget lays them out:
       every STEP after opening, up to closing, none inside a break. Today starts
       at the next step at least LEAD_MIN away, with "now" in front while the
       office is open - so late in the day the list empties and the day drops
       off by itself rather than offering a call that has already passed. */
    function slotsFor(d) {
      var h = dayHours(d), out = [];
      if (!h) return out;
      var start = hm(h.work_start), end = hm(h.work_end),
          bs = h.break_start ? hm(h.break_start) : -1, be = h.break_end ? hm(h.break_end) : -1,
          now = tbNow(), first = start + STEP_MIN;
      if (sameDay(d, now)) {
        if (canCallNow()) out.push({ value: 'now', label: T.nowOpt });
        var lead = now.getHours() * 60 + now.getMinutes() + LEAD_MIN;
        first = Math.max(first, Math.ceil(lead / STEP_MIN) * STEP_MIN);
      }
      for (var m = first; m < end; m += STEP_MIN) {
        if (bs >= 0 && be >= 0 && m >= bs && m <= be) continue;
        var t = pad(Math.floor(m / 60)) + ':' + pad(m % 60);
        out.push({ value: t, label: t });
      }
      return out;
    }

    // Office days only, and only those with a slot left - so the list never
    // offers a day that has nothing behind it.
    function buildDays() {
      var out = [], d = tbNow(), guard = 0;
      while (out.length < DAYS_AHEAD && guard++ < 21) {
        if (slotsFor(d).length) out.push(new Date(d));
        d.setDate(d.getDate() + 1);
        d.setHours(0, 0, 0, 0);   // past today, days start at the top
      }
      return out;
    }

    /* ---- Citynet ---- the key and the office hours are fetched once and kept
       for ten minutes; a failed fetch is forgotten so the next try starts over. */
    var citynetP = null, citynetAt = 0;
    function cnPost(path, fields) {
      var fd = new FormData();
      Object.keys(fields).forEach(function (k) { fd.append(k, fields[k]); });
      return fetch(FORMS.CITYNET + path, { method: 'POST', body: fd }).then(function (r) {
        if (!r.ok) throw new Error('Citynet ' + path + ': HTTP ' + r.status);
        return r;
      });
    }
    function citynet() {
      if (citynetP && Date.now() - citynetAt < 10 * 60000) return citynetP;
      citynetAt = Date.now();
      citynetP = cnPost('get_api_key.php', { site: FORMS.CITYNET_SITE })
        .then(function (r) { return r.text(); })
        .then(function (key) {
          key = (key || '').trim();
          if (!key) throw new Error('Citynet gave no key for ' + FORMS.CITYNET_SITE);
          return cnPost('get_schedule.php', { apikey: key, site: FORMS.CITYNET_SITE })
            .then(function (r) { return r.json(); })
            .then(function (s) {
              var h = {};
              Object.keys(s || {}).forEach(function (k) {
                var day = s[k];
                if (day && day.work_start && day.work_end) h[parseInt(day.week_day_id, 10)] = day;
              });
              hours = h;
              return { key: key };
            });
        });
      citynetP.catch(function (err) {
        citynetP = null;
        if (window.console) console.error('call-back:', err);
      });
      return citynetP;
    }

    /* Two forms of the same date. The picker column is narrow, so the options
       get the short one ("12 სექ, პარ"); the confirmation and the mail that
       reaches the office get the full one, where there is room and no reason to
       make somebody decode an abbreviation. */
    function dayLabel(d, long) {
      var now = tbNow(), tm = tbNow(); tm.setDate(tm.getDate() + 1);
      if (sameDay(d, now)) return T.today;
      if (sameDay(d, tm))  return T.tomorrow;
      return long ? d.getDate() + ' ' + T.months[d.getMonth()] + ', ' + T.wdays[d.getDay()]
                  : d.getDate() + ' ' + T.mo[d.getMonth()] + ', ' + T.wd[d.getDay()];
    }

    /* ---- Themed dropdown ----
       Built rather than using a <select> because the popup a select opens is
       browser chrome: its border, its corners and the scrollbar down a 31-entry
       time list are drawn by the platform and no CSS reaches them. Follows the
       listbox keyboard pattern, so replacing the native control does not cost
       the keyboard behaviour that came with it. */
    function pickHTML(id) {
      return '<div class="pick" data-pick="' + id + '">' +
          '<button class="pick__btn" type="button" aria-haspopup="listbox" ' +
                  'aria-expanded="false" aria-labelledby="' + id + 'L ' + id + 'V">' +
            '<span class="pick__val" id="' + id + 'V"></span>' +
            '<svg class="pick__arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
                 'stroke-width="2" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>' +
          '</button>' +
          '<div class="pick__list" role="listbox" tabindex="-1" hidden></div>' +
        '</div>';
    }

    function makePick(root) {
      var btn  = root.querySelector('.pick__btn'),
          val  = root.querySelector('.pick__val'),
          list = root.querySelector('.pick__list'),
          items = [], idx = 0, onPick = null;

      function isOpen() { return root.classList.contains('is-open'); }
      function active() {
        for (var i = 0; i < list.children.length; i++) {
          if (list.children[i].classList.contains('is-active')) return i;
        }
        return idx;
      }
      function setActive(i) {
        [].forEach.call(list.children, function (c, n) { c.classList.toggle('is-active', n === i); });
        if (list.children[i]) list.children[i].scrollIntoView({ block: 'nearest' });
      }
      /* Measured against the viewport every time it opens, and flipped above the
         button when there is not room below -- the normal case for the time list,
         which sits near the bottom edge of the panel. */
      function place() {
        var r = btn.getBoundingClientRect();
        list.style.left = r.left + 'px';
        list.style.width = r.width + 'px';
        list.style.top = '0px';                       // measure at a known offset
        var h = list.offsetHeight, below = window.innerHeight - r.bottom - 10;
        list.style.top = (below < h && r.top - 10 > below
          ? Math.max(8, r.top - h - 6)
          : r.bottom + 6) + 'px';
      }
      function open() {
        if (isOpen() || !items.length) return;
        list.hidden = false;
        place();
        root.classList.add('is-open');
        btn.setAttribute('aria-expanded', 'true');
        requestAnimationFrame(function () { list.classList.add('is-in'); });
        setActive(idx);
        list.focus();
      }
      function close(focusBtn) {
        if (!isOpen()) return;
        root.classList.remove('is-open');
        btn.setAttribute('aria-expanded', 'false');
        list.classList.remove('is-in');
        setTimeout(function () { if (!isOpen()) list.hidden = true; }, 170);
        if (focusBtn) btn.focus();
      }
      // silent for a programmatic refill: rebuilding the time list must not look
      // like the visitor picked a time.
      function choose(i, silent) {
        if (!items[i]) return;
        idx = i;
        val.textContent = items[i].label;
        [].forEach.call(list.children, function (c, n) {
          c.setAttribute('aria-selected', n === i ? 'true' : 'false');
        });
        if (onPick && !silent) onPick();
      }

      btn.addEventListener('click', function () { if (isOpen()) close(); else open(); });
      btn.addEventListener('keydown', function (e) {
        if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
      });
      list.addEventListener('click', function (e) {
        var o = e.target.closest('.pick__opt');
        if (o) { choose([].indexOf.call(list.children, o)); close(true); }
      });
      list.addEventListener('keydown', function (e) {
        var i = active(), last = items.length - 1;
        if (e.key === 'ArrowDown')    { e.preventDefault(); setActive(Math.min(last, i + 1)); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(Math.max(0, i - 1)); }
        else if (e.key === 'Home')    { e.preventDefault(); setActive(0); }
        else if (e.key === 'End')     { e.preventDefault(); setActive(last); }
        else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); choose(i); close(true); }
        else if (e.key === 'Escape')  { e.preventDefault(); e.stopPropagation(); close(true); }
      });
      document.addEventListener('click', function (e) {
        if (isOpen() && !root.contains(e.target)) close();
      });
      /* Fixed to the viewport, so it would hang in place while the page moved
         underneath it. Its own scrolling is exempt, or the list would close the
         moment you scrolled it. */
      window.addEventListener('scroll', function (e) {
        if (isOpen() && !list.contains(e.target)) close();
      }, true);
      window.addEventListener('resize', function () { close(); });

      return {
        set: function (next) {
          items = next;
          list.innerHTML = '';
          items.forEach(function (it) {
            var o = document.createElement('div');
            o.className = 'pick__opt';
            o.setAttribute('role', 'option');
            o.textContent = it.label;
            list.appendChild(o);
          });
          idx = 0;
          choose(0, true);
        },
        value:  function () { return items[idx] ? items[idx].value : ''; },
        index:  function () { return idx; },
        change: function (fn) { onPick = fn; },
        close:  function () { close(); }
      };
    }

    var wrap = document.createElement('div');
    wrap.className = 'cbk';
    wrap.innerHTML =
      '<div class="cbk__scrim" data-cbk-close></div>' +
      '<div class="cbk__panel" role="dialog" aria-modal="true" aria-labelledby="cbkTitle">' +
        '<button class="cbk__close" type="button" data-cbk-close aria-label="' + T.close + '">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">' +
          '<path d="M18 6 6 18M6 6l12 12"/></svg></button>' +
        '<h3 id="cbkTitle">' + T.title + '</h3>' +
        '<p class="cbk__sub">' + T.sub + '</p>' +
        '<form class="cbk__form" novalidate>' +
          '<p class="form-msg" hidden></p>' +
          '<div class="cbk__fields">' +
            '<div class="field"><label for="cbkPhone">' + T.phone + '</label>' +
              '<div class="cbk__tel"><span class="cbk__cc">' + FLAG + '+995</span>' +
              '<input id="cbkPhone" type="tel" inputmode="numeric" autocomplete="tel-national" ' +
              'placeholder="5XX XX XX XX" maxlength="13" required></div></div>' +
            '<div class="cbk__row">' +
              '<div class="field"><span class="pick__lbl" id="cbkDayL">' + T.day + '</span>' +
                pickHTML('cbkDay') + '</div>' +
              '<div class="field"><span class="pick__lbl" id="cbkTimeL">' + T.time + '</span>' +
                pickHTML('cbkTime') + '</div>' +
            '</div>' +
          '</div>' +
          // Citynet's SMS step: shown in place of the fields above when it asks for a code
          '<div class="cbk__otp field" hidden><label for="cbkOtp">' + T.otpLabel + '</label>' +
            '<input id="cbkOtp" type="text" inputmode="numeric" autocomplete="one-time-code" ' +
            'maxlength="8" placeholder="• • • •"></div>' +
          '<button class="btn btn--primary cbk__submit" type="submit">' + T.send + '</button>' +
        '</form>' +
        '<a class="cbk__now" href="tel:' + FORMS.TEL + '">' + T.now + '</a>' +
      '</div>';
    document.body.appendChild(wrap);
    georgianCaps(wrap);   // assembled after the first pass, so convert it here

    var form   = wrap.querySelector('.cbk__form'),
        msg    = wrap.querySelector('.form-msg'),
        input  = wrap.querySelector('#cbkPhone'),
        telBox = wrap.querySelector('.cbk__tel'),
        submit = wrap.querySelector('.cbk__submit'),
        sub    = wrap.querySelector('.cbk__sub'),
        fields = wrap.querySelector('.cbk__fields'),
        otpBox = wrap.querySelector('.cbk__otp'),
        otpIn  = wrap.querySelector('#cbkOtp'),
        dayPick  = makePick(wrap.querySelector('[data-pick="cbkDay"]')),
        timePick = makePick(wrap.querySelector('[data-pick="cbkTime"]'));

    var days = [];
    function fillDays() {
      days = buildDays();
      dayPick.set(days.map(function (d) {
        return { value: iso(d), label: dayLabel(d) };
      }));
      fillTimes();
    }
    function fillTimes() {
      var d = days[dayPick.index()] || days[0];
      if (!d) return;
      timePick.set(slotsFor(d));
    }
    dayPick.change(fillTimes);   // a different day has a different set of slots

    // Group as 5XX XX XX XX while typing; the value stays 9 digits underneath.
    function digits() { return input.value.replace(/\D/g, '').slice(0, 9); }
    input.addEventListener('input', function () {
      var d = digits(), p = [d.slice(0, 3), d.slice(3, 5), d.slice(5, 7), d.slice(7, 9)];
      input.value = p.filter(Boolean).join(' ');
      telBox.classList.remove('is-bad');
      if (!msg.hidden && msg.classList.contains('err')) hideMsg();
    });

    function flash(text, type) {
      msg.hidden = false; msg.textContent = text; msg.className = 'form-msg ' + type;
    }
    function hideMsg() { msg.hidden = true; msg.textContent = ''; msg.className = 'form-msg'; }

    /* The SMS step reuses the panel: the number and time fields step aside for a
       code box, and the button becomes "confirm". pending holds the request the
       code belongs to, so it is resent exactly as first sent. */
    var pending = null;
    /* georgianCaps has already capitalised anything CSS shows in caps and marked
       it done, so new text for such an element is capitalised here instead - and
       its aria-label, which georgianCaps froze at the old wording, follows. */
    function setText(el, text) {
      if (el.dataset.caps) { el.textContent = text.toUpperCase(); el.setAttribute('aria-label', text); }
      else el.textContent = text;
    }
    function showOtp(otpId, req) {
      pending = { id: otpId, req: req };
      fields.hidden = true;
      otpBox.hidden = false;
      otpIn.value = '';
      setText(sub, T.otpSub.replace('{p}', input.value));
      setText(submit, T.confirm);
      hideMsg();
      setTimeout(function () { otpIn.focus(); }, 30);
    }
    function resetPanel() {
      pending = null;
      fields.hidden = false;
      otpBox.hidden = true;
      setText(sub, T.sub);
      setText(submit, T.send);
    }

    function open() {
      resetPanel();
      fillDays();                 // rebuilt each time: a page left open goes stale
      hideMsg();
      wrap.classList.add('is-open');
      setTimeout(function () { input.focus(); }, 60);
      if (FORMS.LIVE) citynet().then(function () {
        if (!wrap.classList.contains('is-open') || pending) return;
        fillDays();               // Citynet's hours replace the placeholder ones
        if (!days.length) flash(T.closed, 'err');
      }, function () {});
    }
    function close() {
      dayPick.close(); timePick.close();   // they are fixed, not children of the panel
      wrap.classList.remove('is-open');
      fabPh.focus();
    }

    // Start fetching as soon as someone heads for the button, so the real office
    // hours are usually in before the panel has finished opening.
    ['pointerenter', 'focus', 'touchstart'].forEach(function (ev) {
      fabPh.addEventListener(ev, function () { if (FORMS.LIVE) citynet(); }, { passive: true, once: true });
    });
    fabPh.addEventListener('click', function (e) { e.preventDefault(); open(); });
    wrap.addEventListener('click', function (e) {
      if (e.target.closest('[data-cbk-close]')) close();
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && wrap.classList.contains('is-open')) close();
    });

    /* One request to Citynet. Its answers: {result:"success"} (booked),
       {error:"exists"} (already booked - as good as success), {result:"success",
       message:"otp sent", otp_unique_id} (wants the SMS code), {error:"passed
       date"|"passed time"}, {error:"spam"}. */
    function sendCall(req, otp) {
      submit.disabled = true;
      flash(T.sending, 'ok');
      citynet()
        .then(function (c) {
          var f = { apikey: c.key, phone: req.phone, time: req.time, site: FORMS.CITYNET_SITE };
          if (otp) { f.confirm_otp = otp; f.otp_unique_id = pending.id; }
          return cnPost('request_call.php', f);
        })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          res = res || {};
          if (!otp && res.result === 'success' && res.message === 'otp sent' && res.otp_unique_id) {
            showOtp(res.otp_unique_id, req);
          } else if (res.result === 'success' || res.error === 'exists') {
            track('callback_request', { call_time: req.now ? 'now' : 'scheduled' });
            flash(req.now ? T.okNow : T.ok.replace('{d}', req.dayTxt).replace('{t}', req.timeTxt), 'ok');
            form.reset();
            pending = null;
            setTimeout(function () { if (wrap.classList.contains('is-open')) close(); }, 3200);
          } else if (otp) {
            flash(T.otpBad, 'err');
            otpIn.select();
          } else if (res.error === 'passed date' || res.error === 'passed time') {
            fillDays();
            flash(T.passed, 'err');
          } else {
            throw new Error('Citynet refused: ' + JSON.stringify(res));
          }
        })
        .catch(function (err) {
          flash(T.fail, 'err');
          if (window.console) console.error('call-back:', err);
        })
        .then(function () { submit.disabled = false; });
    }

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if (pending) {                      // the SMS step
        var code = otpIn.value.replace(/\s/g, '');
        if (!code) { flash(T.otpNeed, 'err'); otpIn.focus(); return; }
        sendCall(pending.req, code);
        return;
      }
      var d = digits();
      if (d.length !== 9 || d.charAt(0) !== '5') {
        telBox.classList.add('is-bad');
        flash(T.bad, 'err');
        input.focus();
        return;
      }
      if (!FORMS.LIVE) {
        flash(T.unwired, 'err');
        if (window.console) console.warn('call-back: only works on biomi.ge, nothing was sent');
        return;
      }
      if (!days.length || !timePick.value()) { flash(T.closed, 'err'); return; }

      var when = timePick.value(), now = when === 'now';
      sendCall({
        phone:   d,                                     // 9 digits, the form Citynet's own widget accepts
        time:    now ? stamp(tbNow()) : dayPick.value() + 'T' + when + ':00',
        now:     now,
        dayTxt:  dayLabel(days[dayPick.index()] || days[0], true),
        timeTxt: when
      });
    });
  })();

  var header = document.getElementById('header');
  var toTop  = document.getElementById('toTop');
  /* ---- Header shadow/shrink on scroll + back-to-top ---- */
  function onScroll() {
    var y = window.scrollY || window.pageYOffset;
    header.classList.toggle('is-solid', y > 8);
    if (toTop) toTop.classList.toggle('show', y > 600);
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  if (toTop) toTop.addEventListener('click', function () {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  /* ---- Hero: infinite auto-carousel; mouse-move direction steers it, and it
     can be dragged (mouse) or swiped (touch). A drag moves the same offset the
     animation does, so the loop never breaks; letting go leaves a little
     momentum that fades back into the auto-scroll, in the direction dragged. ---- */
  (function () {
    var vp = document.querySelector('.hero__viewport');
    var track = document.querySelector('.hero__track');
    if (!vp || !track) return;

    var offset = 0;          // px the track is shifted left
    var setW = 0;            // width of one image set (half the duplicated track)
    var speed = 1.0;         // auto-scroll px per frame
    var dir = 1;             // 1 = images move left (default), -1 = move right
    var lastX = null;
    var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var DRAG_START = 6;      // px of travel before a press counts as a drag, not a click
    var drag = null;         // { id, x0, off0, lastX, lastT, v, moved } while a pointer is down
    var fling = 0;           // px per frame left over from a drag, decaying to 0
    var swallowClick = false;

    function measure() { setW = track.scrollWidth / 2; }
    measure();
    window.addEventListener('resize', measure);
    window.addEventListener('load', measure);

    function wrap() {
      if (setW <= 0) return;
      if (offset >= setW) offset -= setW;
      else if (offset < 0) offset += setW;
    }
    function render() { track.style.transform = 'translateX(' + (-offset) + 'px)'; }

    function tick() {
      if (!(drag && drag.moved)) {
        if (!reduce) offset += speed * dir;
        if (fling) {
          offset += fling;
          fling *= 0.94;
          if (Math.abs(fling) < 0.05) fling = 0;
        }
        wrap(); render();
      }
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);

    // Move the mouse over the images to steer direction (no clicking)
    vp.addEventListener('pointermove', function (e) {
      if (drag) return;
      if (lastX !== null) {
        var dx = e.clientX - lastX;
        if (dx > 1) dir = -1;        // mouse moves right -> images move right
        else if (dx < -1) dir = 1;   // mouse moves left  -> images move left
      }
      lastX = e.clientX;
    });
    vp.addEventListener('pointerleave', function () { if (!drag) { lastX = null; dir = 1; } }); // back to default

    // ---- drag / swipe ----
    // The pointer is only captured once the press has travelled DRAG_START px:
    // capturing on pointerdown would retarget a plain click to the viewport, and
    // the cards are links that have to keep working.
    vp.addEventListener('pointerdown', function (e) {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      drag = { id: e.pointerId, x0: e.clientX, off0: offset, lastX: e.clientX, lastT: e.timeStamp, v: 0, moved: false };
      fling = 0;
    });
    vp.addEventListener('pointermove', function (e) {
      if (!drag || e.pointerId !== drag.id) return;
      var dx = e.clientX - drag.x0;
      if (!drag.moved) {
        if (Math.abs(dx) < DRAG_START) return;
        drag.moved = true;
        vp.classList.add('is-dragging');
        try { vp.setPointerCapture(e.pointerId); } catch (err) {}
      }
      offset = drag.off0 - dx;
      wrap(); render();
      // re-base after a wrap so the next move does not jump a whole set
      drag.off0 = offset + dx;
      var dt = Math.max(1, e.timeStamp - drag.lastT);
      // px per frame (~16.7ms), smoothed; positive = images moving left
      drag.v = 0.7 * drag.v + 0.3 * (-(e.clientX - drag.lastX) / dt * 16.7);
      drag.lastX = e.clientX; drag.lastT = e.timeStamp;
    });
    function endDrag(e) {
      if (!drag || (e && e.pointerId !== drag.id)) return;
      if (drag.moved) {
        swallowClick = true;                       // the click that follows a drag is not a click
        fling = Math.max(-40, Math.min(40, drag.v));
        if (Math.abs(drag.v) > 0.5) dir = drag.v > 0 ? 1 : -1;  // carry on the way it was thrown
        vp.classList.remove('is-dragging');
        try { vp.releasePointerCapture(drag.id); } catch (err) {}
        setTimeout(function () { swallowClick = false; }, 0);
      }
      drag = null;
    }
    vp.addEventListener('pointerup', endDrag);
    vp.addEventListener('pointercancel', endDrag);   // e.g. the browser took over for a vertical scroll
    vp.addEventListener('click', function (e) {
      if (swallowClick) { e.preventDefault(); e.stopPropagation(); swallowClick = false; }
    }, true);
    // links and background images would otherwise start the browser's own drag-and-drop
    vp.addEventListener('dragstart', function (e) { e.preventDefault(); });
  })();

  /* ---- Language toggle (GEO/ENG pills) - placeholder until ENG is built ---- */
  document.querySelectorAll('.lang, .drawer__langs').forEach(function (group) {
    group.querySelectorAll('button').forEach(function (btn) {
      btn.addEventListener('click', function () {
        group.querySelectorAll('button').forEach(function (b) { b.classList.remove('is-active'); });
        btn.classList.add('is-active');
      });
    });
  });

  /* ---- Dark mode ----
     The theme is already on <html> by the time this runs -- the inline script in
     every <head> does that before first paint so the page never flashes white.
     All this adds is the switch: one in the header toolbar, one in the drawer
     (the toolbar is hidden on phones). Injected rather than written into 45
     pages of markup, so a new page picks it up for free.

     The site opens dark. No stored choice means dark, whatever the machine is
     set to; only the switch changes it, and only that is remembered. */
  (function () {
    var THEME_KEY = 'biomi-theme';
    var root = document.documentElement;
    var en = (root.lang || 'ka').slice(0, 2) === 'en';
    var SUN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">' +
      '<circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2' +
      'M5.2 5.2l1.4 1.4M17.4 17.4l1.4 1.4M18.8 5.2l-1.4 1.4M6.6 17.4l-1.4 1.4"/></svg>';
    var MOON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" ' +
      'stroke-linejoin="round"><path d="M20 14.2A8.2 8.2 0 0 1 9.8 4a8.4 8.4 0 1 0 10.2 10.2Z"/></svg>';
    var btns = [];

    function label(dark) {
      return en ? (dark ? 'Switch to light mode' : 'Switch to dark mode')
                : (dark ? 'ნათელ რეჟიმზე გადართვა' : 'ბნელ რეჟიმზე გადართვა');
    }
    /* The header and drawer carry a dedicated dark-mode lockup - white wordmark,
       blue mark intact - rather than a filtered version of the light one. The
       path is derived from whatever src the page already has (logo-geo.svg ->
       logo-geo-dark.svg), so this works from the root and from /products alike
       and no page needs to name both files.

       Which one shows depends on the backdrop, not the theme: the header also
       turns solid navy on scroll, and that is just as dark as dark mode, so it
       takes the dark lockup in either theme. The drawer panel is always the
       surface colour, so it follows the theme alone.

       The footer is navy in both themes, so it always wants the dark lockup.
       That one keeps its CSS knock-out as a no-JS fallback and only drops the
       filter once the real artwork is actually in place. The header needs no
       such fallback: .is-solid is set by the scroll handler above, so without
       JS it never goes navy in the first place.

       Manufacturer logos work the same way where a dark version exists. Only
       the two below have one, so the rest keep the CSS knock-out - hence the
       explicit list rather than probing for a file. */
    var headerEl = document.querySelector('.header');
    var DARK_PARTNERS = /(samsung|mitsubishi-electric)\.svg/;
    var logos = [];

    function register(img, opts) {
      var light = img.getAttribute('src');
      opts.img = img;
      opts.light = light;
      opts.dark = light.replace(/\.svg/, '-dark.svg');    // white type, purple mark
      opts.solid = light.replace(/\.svg/, '-solid.svg');  // white type, blue mark
      // warm the cache so the first swap doesn't blink
      new Image().src = opts.dark;
      if (opts.hasSolid) new Image().src = opts.solid;
      logos.push(opts);
    }

    document.querySelectorAll('.header .brand__logo, .drawer__panel .brand__logo, .footer .brand__logo')
      .forEach(function (img) {
        if (!/logo-(geo|eng)\.svg/.test(img.getAttribute('src'))) return;
        register(img, {
          onSolid: !!(headerEl && headerEl.contains(img)),
          always: !!img.closest('.footer'),   // footer is navy in both themes
          knockout: !!img.closest('.footer'),
          hasSolid: true                      // the Biomi lockup has a blue-mark variant
        });
      });

    document.querySelectorAll('.brandpick__card img, .brand-hero__logo').forEach(function (img) {
      if (!DARK_PARTNERS.test(img.getAttribute('src'))) return;
      register(img, { onSolid: false, always: false, knockout: true });
    });

    function paintLogos() {
      var themeDark = root.getAttribute('data-theme') === 'dark';
      var solid = !!(headerEl && headerEl.classList.contains('is-solid'));
      logos.forEach(function (l) {
        // Two separate questions: is the backdrop dark (so the typography must
        // go white), and which theme are we in (so the mark matches the accent
        // - blue in light, purple in dark). The scrolled header and the footer
        // are dark backdrops in *light* mode too, and there the mark stays blue.
        var wantDark = l.always || themeDark || (l.onSolid && solid);
        var want = !wantDark ? l.light
                 : (themeDark || !l.hasSolid) ? l.dark
                 : l.solid;
        if (l.img.getAttribute('src') !== want) l.img.setAttribute('src', want);
        // these carry a CSS knock-out as the no-JS fallback; drop it once the
        // real artwork is in, so the Mitsubishi red survives instead of going flat
        if (l.knockout) l.img.style.filter = wantDark ? 'none' : '';
      });
    }
    if (headerEl && window.MutationObserver) {
      new MutationObserver(paintLogos).observe(headerEl, { attributes: true, attributeFilter: ['class'] });
    }

    function paint() {
      var dark = root.getAttribute('data-theme') === 'dark';
      paintLogos();
      btns.forEach(function (b) {
        b.innerHTML = (dark ? SUN : MOON) + (b.dataset.withText ? '<span>' + (en ? 'Theme' : 'თემა') + '</span>' : '');
        b.setAttribute('aria-label', label(dark));
        b.setAttribute('title', label(dark));
        b.setAttribute('aria-pressed', dark ? 'true' : 'false');
      });
    }
    function set(theme, remember) {
      root.setAttribute('data-theme', theme);
      if (remember) { try { localStorage.setItem(THEME_KEY, theme); } catch (e) {} }
      paint();
    }
    function make(cls, withText) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = cls;
      if (withText) b.dataset.withText = '1';
      b.addEventListener('click', function () {
        set(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark', true);
      });
      btns.push(b);
      return b;
    }

    var tools = document.querySelector('.nav__tools');
    if (tools) {
      var search = tools.querySelector('.icon-btn');
      tools.insertBefore(make('icon-btn theme-btn', false), search || tools.lastElementChild);
    }
    var foot = document.querySelector('.drawer__foot');
    if (foot) foot.insertBefore(make('drawer__theme', true), foot.firstElementChild);
    paint();

    /* No OS listener. The site opens dark whatever the machine is set to, so
       following the system afterwards would undo that the moment a visitor on
       a light desktop happened to change it -- and a page that starts dark and
       turns light while you are reading it looks broken rather than helpful.
       The switch still wins, and its choice is what localStorage holds. */
  })();

  /* ---- Site search ----
     The magnifier in the toolbar was decorative. It now opens an overlay that
     searches a prebuilt index (assets/search-<lang>.json, generated from the
     hub pages' product cards plus a short list of standalone pages).

     The index is fetched on first open, not on load, so it costs nothing to
     visitors who never search. Paths inside it are root-relative; the "../"
     prefix a page needs is read off its own stylesheet href, which is the one
     link every page already has and which already encodes its depth. */
  (function () {
    var tools = document.querySelector('.nav__tools');
    var trigger = tools && tools.querySelector('.icon-btn:not(.theme-btn)');
    if (!trigger) return;

    var en = (document.documentElement.lang || 'ka').slice(0, 2) === 'en';
    var cssHref = (document.querySelector('link[rel="stylesheet"]') || {}).getAttribute
      ? document.querySelector('link[rel="stylesheet"]').getAttribute('href') : '';
    var base = cssHref.indexOf('assets/') > 0 ? cssHref.slice(0, cssHref.indexOf('assets/')) : '';

    var T = en
      ? { ph: 'Search products and pages…', none: 'Nothing found for', esc: 'close', label: 'Search' }
      : { ph: 'მოძებნეთ პროდუქტი ან გვერდი…', none: 'ვერაფერი მოიძებნა:', esc: 'დახურვა', label: 'ძიება' };

    var wrap = document.createElement('div');
    wrap.className = 'srch';
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-modal', 'true');
    wrap.setAttribute('aria-label', T.label);
    wrap.innerHTML =
      '<div class="srch__scrim" data-srch-close></div>' +
      '<div class="srch__panel">' +
        '<div class="srch__bar">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
            '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>' +
          '<input type="search" autocomplete="off" spellcheck="false" placeholder="' + T.ph + '" aria-label="' + T.label + '">' +
          '<button class="srch__close" type="button" data-srch-close>ESC</button>' +
        '</div>' +
        '<div class="srch__results" role="listbox"></div>' +
      '</div>';
    document.body.appendChild(wrap);

    var input = wrap.querySelector('input');
    var out = wrap.querySelector('.srch__results');
    var data = null, loading = false, sel = -1, hits = [];

    function esc(s) {
      return String(s).replace(/[&<>"]/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
      });
    }

    function render() {
      var q = input.value.toLowerCase().trim();
      if (!data || !q) { out.innerHTML = ''; hits = []; sel = -1; return; }
      var terms = q.split(/\s+/);
      hits = data.filter(function (it) {
        for (var i = 0; i < terms.length; i++) if (it.q.indexOf(terms[i]) < 0) return false;
        return true;
      }).slice(0, 12);
      sel = hits.length ? 0 : -1;
      if (!hits.length) {
        out.innerHTML = '<div class="srch__empty">' + T.none + ' “' + esc(input.value.trim()) + '”</div>';
        return;
      }
      out.innerHTML = hits.map(function (it, i) {
        var thumb = it.img
          ? '<span class="srch__thumb"><img src="' + base + esc(it.img) + '" alt=""></span>'
          : '';
        return '<a class="srch__item' + (i === sel ? ' is-sel' : '') + '" role="option" href="' + base + esc(it.url) + '">' +
          thumb +
          '<span class="srch__txt"><span class="srch__title">' + esc(it.title) + '</span>' +
          (it.sub ? '<span class="srch__meta">' + esc(it.sub) + '</span>' : '') +
          '</span><span class="srch__kind">' + esc(it.kind) + '</span></a>';
      }).join('');
    }

    function move(step) {
      if (!hits.length) return;
      sel = (sel + step + hits.length) % hits.length;
      var items = out.querySelectorAll('.srch__item');
      items.forEach(function (el, i) { el.classList.toggle('is-sel', i === sel); });
      if (items[sel]) items[sel].scrollIntoView({ block: 'nearest' });
    }

    function load() {
      if (data || loading) return;
      loading = true;
      fetch(base + 'assets/search-' + (en ? 'en' : 'ka') + '.json')
        .then(function (r) { return r.ok ? r.json() : []; })
        .then(function (j) { data = j; render(); })
        .catch(function () { data = []; })
        .then(function () { loading = false; });
    }

    function open() {
      load();
      wrap.classList.add('open');
      document.body.style.overflow = 'hidden';
      setTimeout(function () { input.focus(); }, 60);
    }
    function close() {
      wrap.classList.remove('open');
      document.body.style.overflow = '';
      trigger.focus();
    }

    trigger.addEventListener('click', open);
    // a search button in the page itself (the 404 page's) opens the same overlay
    document.querySelectorAll('[data-open-search]').forEach(function (el) { el.addEventListener('click', open); });
    wrap.querySelectorAll('[data-srch-close]').forEach(function (el) { el.addEventListener('click', close); });
    input.addEventListener('input', render);
    wrap.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { e.preventDefault(); close(); }
      else if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
      else if (e.key === 'Enter' && hits[sel]) { e.preventDefault(); location.href = base + hits[sel].url; }
    });
    document.addEventListener('keydown', function (e) {
      // Ctrl/Cmd-K from anywhere, and "/" when not already typing somewhere
      var typing = /^(INPUT|TEXTAREA|SELECT)$/.test((document.activeElement || {}).tagName || '');
      if (((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') || (e.key === '/' && !typing && !wrap.classList.contains('open'))) {
        e.preventDefault(); open();
      }
    });

    // the toolbar is hidden on phones, so the drawer gets its own way in
    var foot = document.querySelector('.drawer__foot');
    if (foot) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'drawer__theme';
      b.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
        '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg><span>' + T.label + '</span>';
      b.addEventListener('click', function () {
        var d = document.getElementById('drawer');
        if (d) { d.classList.remove('open'); document.body.style.overflow = ''; }
        open();
      });
      foot.insertBefore(b, foot.firstElementChild);
    }
  })();

  /* ---- Mobile drawer ---- */
  var burger = document.getElementById('burger');
  var drawer = document.getElementById('drawer');
  function openDrawer() { drawer.classList.add('open'); burger.setAttribute('aria-expanded', 'true'); document.body.style.overflow = 'hidden'; }
  function closeDrawer() { drawer.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); document.body.style.overflow = ''; }
  if (burger) burger.addEventListener('click', openDrawer);
  if (drawer) drawer.querySelectorAll('[data-close]').forEach(function (el) { el.addEventListener('click', closeDrawer); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && drawer.classList.contains('open')) closeDrawer();
  });

  /* ---- Products dropdown: a flyout ----
     Pointing at a chapter slides its categories out beside the column (CSS
     .is-active), the way the chapter rail on products.html switches on hover.
     The way from a chapter to its flyout usually crosses the chapters under
     it, so once one is open a switch waits INTENT ms and is dropped if the
     pointer reaches the open flyout first -- otherwise heading for "boilers"
     would open cooling on the way. The caret still toggles on a click, for a
     touchscreen and the keyboard; the name itself is a link to the chapter. */
  document.querySelectorAll('.prod-menu').forEach(function (menu) {
    var INTENT = 150;
    var chapters = Array.prototype.slice.call(menu.querySelectorAll('.prod-menu__chapter'));
    var item = menu.closest('.nav__item');
    var timer = null, closer = null;
    var hover = window.matchMedia('(hover:hover)');

    // Open the flyout on the left when there is no room for it on the right --
    // the menu hangs under a nav item that is right of centre.
    function flip(ch) {
      var panel = ch.querySelector('.prod-menu__panel');
      var r = menu.getBoundingClientRect();
      var w = panel ? (panel.offsetWidth || 290) : 290;
      menu.classList.toggle('prod-menu--flip', r.right + w > document.documentElement.clientWidth - 12);
    }
    function activate(ch) {
      clearTimeout(timer); timer = null;
      if (ch) flip(ch);
      chapters.forEach(function (o) {
        var on = o === ch;
        o.classList.toggle('is-active', on);
        var b = o.querySelector('.prod-menu__btn');
        if (b) b.setAttribute('aria-expanded', on ? 'true' : 'false');
      });
    }
    chapters.forEach(function (ch) {
      var head = ch.querySelector('.prod-menu__head') || ch.querySelector('.prod-menu__btn');
      var panel = ch.querySelector('.prod-menu__panel');
      var btn = ch.querySelector('.prod-menu__btn');
      head.addEventListener('mouseenter', function () {
        if (!hover.matches) return;
        clearTimeout(timer);
        if (ch.classList.contains('is-active')) return;
        var anyOpen = chapters.some(function (o) { return o.classList.contains('is-active'); });
        if (anyOpen) timer = setTimeout(function () { activate(ch); }, INTENT);
        else activate(ch);
      });
      if (panel) panel.addEventListener('mouseenter', function () { clearTimeout(timer); timer = null; });
      if (btn) btn.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        activate(ch.classList.contains('is-active') ? null : ch);
      });
      ch.addEventListener('focusin', function () { if (!ch.classList.contains('is-active')) activate(ch); });
    });
    // Closing the menu closes the flyout too, once the menu has faded out, so
    // the next time it opens it starts from the column alone.
    if (item) {
      item.addEventListener('mouseleave', function () {
        clearTimeout(closer);
        closer = setTimeout(function () { activate(null); }, 260);
      });
      item.addEventListener('mouseenter', function () { clearTimeout(closer); });
    }
  });



  /* ---- Homepage products rail ----
     The five chapters stay on one line at every width, so below the point
     where they all fit the row scrolls sideways. The native scrollbar was the
     only hint that it did, and it read as an artefact rather than a control,
     so it is hidden in CSS and these arrows take over. They are revealed only
     while the row actually overflows -- at full width all five are visible and
     nothing appears. */
  document.querySelectorAll('.rail').forEach(function (rail) {
    var grid = rail.querySelector('.prod-grid, .news-grid, .proj-grid');
    var prev = rail.querySelector('.rail__prev');
    var next = rail.querySelector('.rail__next');
    if (!grid || !prev || !next) return;

    function step() {
      var card = grid.querySelector('.prod, .news, .proj');
      var gap = parseFloat(getComputedStyle(grid).columnGap) || 14;
      return card ? card.getBoundingClientRect().width + gap : 240;
    }
    function sync() {
      var slack = grid.scrollWidth - grid.clientWidth;
      rail.classList.toggle('is-scrollable', slack > 2);
      prev.disabled = grid.scrollLeft <= 1;
      next.disabled = grid.scrollLeft >= slack - 1;
    }
    prev.addEventListener('click', function () { grid.scrollBy({ left: -step(), behavior: 'smooth' }); });
    next.addEventListener('click', function () { grid.scrollBy({ left: step(), behavior: 'smooth' }); });
    grid.addEventListener('scroll', sync);
    window.addEventListener('resize', sync);
    sync();
  });



  /* ---- About section: collapse the copy on phones ----
     The section is the second tallest on the homepage and the two paragraphs
     are a third of its height. Rather than cut any of the text it collapses to
     roughly six lines behind a toggle. Progressive enhancement on purpose: the
     wrapper and button are built here, so with JS off the full copy shows. The
     button only appears when the copy actually overflows, which keeps it away
     from wide viewports and from shorter translations. */
  (function () {
    var text = document.querySelector('.about__text');
    if (!text) return;
    var ps = Array.prototype.slice.call(text.querySelectorAll(':scope > p'));
    if (ps.length < 2) return;

    var copy = document.createElement('div');
    copy.className = 'about__copy';
    ps[0].parentNode.insertBefore(copy, ps[0]);
    ps.forEach(function (p) { copy.appendChild(p); });

    var en = (document.documentElement.lang || 'ka').indexOf('en') === 0;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'about__more';
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-controls', 'about-copy');
    copy.id = 'about-copy';
    var LESS = en ? 'Show less' : 'ნაკლების ჩვენება';
    var MORE = en ? 'Show more' : 'მეტის ჩვენება';
    btn.textContent = MORE;
    copy.parentNode.insertBefore(btn, copy.nextSibling);

    btn.addEventListener('click', function () {
      var open = copy.classList.toggle('is-open');
      btn.textContent = open ? LESS : MORE;
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });

    function sync() {
      // clipped only where the CSS clamp applies, so ask the layout rather than
      // duplicating the breakpoint here
      var clamped = copy.scrollHeight - copy.clientHeight > 4;
      btn.hidden = !clamped && !copy.classList.contains('is-open');
    }
    window.addEventListener('resize', sync);
    sync();
  })();

  /* ---- Product catalogue: the chapter row (products.html) ----
     The five chapters are a row with one open panel under it rather than five
     columns side by side. Every panel is in the markup; this adds the class the
     CSS hangs the whole behaviour off, so with the script off the row is never
     shown and the page stays five stacked chapters.

     The tab roles are written here rather than in the generated markup for the
     same reason: buttons that switch nothing are not tabs, and that is exactly
     what they would be if this never ran. */
  (function () {
    var wrap = document.querySelector('.catalog');
    if (!wrap) return;
    var rail = wrap.querySelector('.catalog__rail');
    var tabs = [].slice.call(wrap.querySelectorAll('.cat-tab'));
    var panels = [].slice.call(wrap.querySelectorAll('.catalog__chapter'));
    if (!rail || !tabs.length || !panels.length) return;

    wrap.classList.add('catalog--tabs');
    rail.setAttribute('role', 'tablist');
    // horizontal while the chapters are a row; the media query stacks them at 900px
    rail.setAttribute('aria-orientation', 'horizontal');
    panels.forEach(function (p) {
      var ch = p.getAttribute('data-ch');
      if (!p.id) p.id = 'catp-' + ch;
      p.setAttribute('role', 'tabpanel');
    });
    tabs.forEach(function (t) {
      var ch = t.getAttribute('data-ch');
      var panel = panels.filter(function (p) { return p.getAttribute('data-ch') === ch; })[0];
      if (!t.id) t.id = 'catt-' + ch;
      t.setAttribute('role', 'tab');
      if (panel) {
        t.setAttribute('aria-controls', panel.id);
        panel.setAttribute('aria-labelledby', t.id);
      }
    });

    function show(ch, focus) {
      tabs.forEach(function (t) {
        var on = t.getAttribute('data-ch') === ch;
        t.classList.toggle('is-on', on);
        t.setAttribute('aria-selected', on ? 'true' : 'false');
        /* Roving tabindex: one stop for the whole rail, and the arrows move
           within it. Five separate tab stops in front of the page's content is
           what a tablist exists to avoid. */
        t.tabIndex = on ? 0 : -1;
        if (on && focus) t.focus();
      });
      panels.forEach(function (p) {
        p.classList.toggle('is-on', p.getAttribute('data-ch') === ch);
      });
    }

    tabs.forEach(function (t, i) {
      var ch = t.getAttribute('data-ch');
      t.addEventListener('click', function () { show(ch); });
      /* Hover switches as well, which is the whole point of a rail: the panel
         is where the pointer is already heading. Guarded on a hovering pointer
         so a tap on a touchscreen does not fire this and the click both. */
      t.addEventListener('mouseenter', function () {
        if (window.matchMedia('(hover:hover)').matches) show(ch);
      });
      t.addEventListener('keydown', function (e) {
        var k = e.key, n = -1;
        if (k === 'ArrowDown' || k === 'ArrowRight') n = (i + 1) % tabs.length;
        else if (k === 'ArrowUp' || k === 'ArrowLeft') n = (i - 1 + tabs.length) % tabs.length;
        else if (k === 'Home') n = 0;
        else if (k === 'End') n = tabs.length - 1;
        if (n < 0) return;
        e.preventDefault();
        show(tabs[n].getAttribute('data-ch'), true);
      });
    });

    /* products.html#ventilation opens that chapter, on arrival and on a link
       followed while the page is already open -- a hash-only change loads
       nothing, so without the listener the rail would ignore it. Read only:
       switching does not write the hash back, or hovering down the rail would
       fill the history with chapters nobody chose. */
    function fromHash(fallback) {
      var want = decodeURIComponent(location.hash.replace('#', ''));
      var hit = tabs.filter(function (t) { return t.getAttribute('data-ch') === want; })[0];
      if (hit) show(want);
      else if (fallback) show(tabs[0].getAttribute('data-ch'));
    }
    window.addEventListener('hashchange', function () { fromHash(false); });
    fromHash(true);
  })();

  /* ---- Horizontal strips: fade whichever edge still has content beyond it ----
     A permanent fade on both sides (the treatment the logo marquee uses) would
     dim the first and last thumbnail even when there is nothing past them, so
     the state is driven from the scroll position instead. No overflow means
     neither class is set and the strip renders unmasked. */
  /* .catalog__rail is a column until 900px and a row of chapter pills below it.
     Adding it here costs nothing at full width: with no overflow neither class
     is set, so the mask stays the no-op gradient and the column renders unfaded. */
  document.querySelectorAll('.gallery,.prod-grid,.news-grid,.proj-grid,.catalog__rail').forEach(function (g) {
    g.classList.add('edgefade');
    function update() {
      var over = g.scrollWidth - g.clientWidth;
      g.classList.toggle('has-left', over > 2 && g.scrollLeft > 2);
      g.classList.toggle('has-right', over > 2 && g.scrollLeft < over - 2);
    }
    g.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    // images arrive after layout, so re-measure once they have decoded
    g.querySelectorAll('img').forEach(function (im) {
      if (!im.complete) im.addEventListener('load', update, { once: true });
    });
    update();
  });

  /* ---- Image lightbox with prev/next (grouped per gallery) ---- */
  /* Product pages drive this from their .pgal gallery rather than [data-lightbox]
     markup: those thumbs already own a click handler that swaps the main image,
     so tagging them would double-bind. The gallery lives in a *separate*
     top-level IIFE further down this file and shares no scope with this one, so
     the two talk over a 'biomi:lightbox' document event rather than a variable. */
  (function () {
    var all = Array.prototype.slice.call(document.querySelectorAll('[data-lightbox]'));
    // still build it when a page has no [data-lightbox] but does have a gallery
    if (!all.length && !document.querySelector('.pgal__main img')) return;
    // group images by their container so arrows cycle within one gallery
    var groups = [];
    all.forEach(function (im) {
      // Group per article, not per container. The hero sits in <figure
      // class="article__img"> and the rest in <div class="gallery">, so keying
      // on parentElement made the hero a group of one -- open it and the arrows
      // had nowhere to go. The ducting grid is the same case: every card is its
      // own <span>, so the whole range groups on .pgrid instead and the arrows
      // walk it. Anything outside both still groups by its own container.
      var parent = im.closest('.article') || im.closest('.pgrid') || im.closest('.pstations') || im.parentElement;
      var g = null;
      for (var i = 0; i < groups.length; i++) { if (groups[i].parent === parent) { g = groups[i]; break; } }
      if (!g) { g = { parent: parent, items: [] }; groups.push(g); }
      g.items.push(im);
    });

    var lb = document.createElement('div');
    lb.className = 'lightbox';
    lb.innerHTML =
      '<button class="lightbox__close" type="button" aria-label="დახურვა"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M18 6 6 18M6 6l12 12"/></svg></button>' +
      '<button class="lightbox__nav lightbox__prev" type="button" aria-label="წინა"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m15 6-6 6 6 6"/></svg></button>' +
      '<div class="lightbox__stage">' +
        '<img alt="">' +
        '<iframe class="lightbox__frame" style="display:none" allow="autoplay; encrypted-media; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>' +
        '<p class="lightbox__cap" aria-live="polite"></p>' +
      '</div>' +
      '<button class="lightbox__nav lightbox__next" type="button" aria-label="შემდეგი"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m9 6 6 6-6 6"/></svg></button>';
    document.body.appendChild(lb);
    var lbImg = lb.querySelector('img');
    var frame = lb.querySelector('.lightbox__frame');
    var cap = lb.querySelector('.lightbox__cap');

    /* The name under the enlarged picture, read from the card the picture sits
       in: a ducting part's <b> name, a pumping station's make and range, a news
       photo's caption. data-caption on the image wins if a page wants to say
       something else. Nothing found, nothing shown. */
    function captionFor(im) {
      var own = im.getAttribute('data-caption');
      if (own) return own;
      var fc = im.closest('figure') && im.closest('figure').querySelector('figcaption');
      if (!fc) return '';
      var b = fc.querySelector('b');
      if (b) {
        var sub = b.nextElementSibling && b.nextElementSibling.tagName === 'SMALL' ? b.nextElementSibling.textContent.trim() : '';
        return b.textContent.trim() + (sub ? ' · ' + sub : '');
      }
      return fc.textContent.replace(/\s+/g, ' ').trim();
    }
    var prevBtn = lb.querySelector('.lightbox__prev');
    var nextBtn = lb.querySelector('.lightbox__next');
    var group = null, index = 0, onClose = null;

    function render() {
      var im = group.items[index];
      var vid = im.getAttribute('data-video');
      if (vid) {
        lbImg.style.display = 'none';
        frame.style.display = '';
        frame.src = 'https://www.youtube-nocookie.com/embed/' + vid + '?autoplay=1&rel=0';
      } else {
        frame.src = '';
        frame.style.display = 'none';
        lbImg.style.display = '';
        lbImg.src = im.getAttribute('data-full') || im.src;
        lbImg.alt = im.alt || '';
      }
      var text = captionFor(im);
      cap.textContent = text;
      lb.classList.toggle('has-cap', !!text);
      var multi = group.items.length > 1;
      prevBtn.style.display = nextBtn.style.display = multi ? '' : 'none';
    }
    function step(d) { index = (index + d + group.items.length) % group.items.length; render(); }
    function open(g, i) { group = g; index = i; render(); lb.classList.add('open'); document.body.style.overflow = 'hidden'; }
    function close() {
      frame.src = ''; lb.classList.remove('open'); document.body.style.overflow = '';
      // let the caller sync to whichever slide you left on
      if (onClose) { var cb = onClose; onClose = null; cb(index); }
    }

    /* Open an arbitrary image list on request - detail: {items, index, onClose}.
       Used by the .pgal product gallery, which cannot reach `open` directly. */
    document.addEventListener('biomi:lightbox', function (e) {
      var d = e.detail || {};
      if (!d.items || !d.items.length) return;
      onClose = typeof d.onClose === 'function' ? d.onClose : null;
      open({ parent: null, items: d.items }, d.index || 0);
    });

    groups.forEach(function (g) {
      g.items.forEach(function (im, i) {
        im.style.cursor = 'zoom-in';
        im.addEventListener('click', function () { open(g, i); });
      });
    });
    prevBtn.addEventListener('click', function (e) { e.stopPropagation(); step(-1); });
    nextBtn.addEventListener('click', function (e) { e.stopPropagation(); step(1); });
    lb.addEventListener('click', function (e) {
      if (e.target === lb || e.target.closest('.lightbox__close')) close();
    });
    document.addEventListener('keydown', function (e) {
      if (!lb.classList.contains('open')) return;
      if (e.key === 'Escape') close();
      else if (e.key === 'ArrowLeft') step(-1);
      else if (e.key === 'ArrowRight') step(1);
    });
  })();

  /* ---- Video facade: poster + play button, loads the player only on click ---- */
  document.querySelectorAll('.video-facade[data-video]').forEach(function (f) {
    f.addEventListener('click', function () {
      var id = f.getAttribute('data-video');
      var ifr = document.createElement('iframe');
      ifr.src = 'https://www.youtube-nocookie.com/embed/' + id + '?autoplay=1&rel=0';
      ifr.title = f.getAttribute('aria-label') || 'YouTube video';
      ifr.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      ifr.setAttribute('allowfullscreen', '');
      ifr.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      ifr.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;border:0';
      f.replaceWith(ifr);
    });
  });

  /* ---- Subsection tabs (Samsung: DVM / CAC / FJM) ---- */
  document.querySelectorAll('.subtabs').forEach(function (tabs) {
    var btns = tabs.querySelectorAll('.subtabs__btn');
    var panels = tabs.querySelectorAll('.subtabs__panel');
    btns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var key = btn.getAttribute('data-tab');
        btns.forEach(function (b) { b.classList.toggle('active', b === btn); });
        panels.forEach(function (p) { p.classList.toggle('active', p.getAttribute('data-panel') === key); });
      });
    });
  });

  /* ---- Drawer chapters (inside the products accordion) ----
     Opening one has to grow the accordion above it as well, or the chapter
     expands into a panel that is still only as tall as the collapsed list. The
     parent height is recomputed from its rows rather than measured, because at
     the moment of the click this panel is at t=0 of its own transition and
     still reports zero. */
  /* Three levels of disclosure now: the Products accordion, the chapters inside
     it, and each subsection's brand list. Every level animates max-height in
     pixels, so a parent's height has to be computed from its children's natural
     sizes rather than read back off the DOM -- an element mid-transition reports
     its current clipped height, which is what made the chapter collapse the
     first time a nested menu was added to the desktop nav. scrollHeight is safe
     on a *panel* (it measures content, not the clipped box) but not on an
     ancestor whose child is still animating. */
  function itmPanelHeight(panel) {
    var h = 0;
    Array.prototype.forEach.call(panel.children, function (c) {
      if (c.classList.contains('m-itm')) {
        var head = c.querySelector('.m-itm__head');
        var sub = c.querySelector('.m-itm__panel');
        if (head) h += head.offsetHeight;
        if (sub && c.classList.contains('open')) h += sub.scrollHeight;
      } else {
        h += c.offsetHeight;
      }
    });
    return h;
  }
  function acctHeight(outer) {
    var h = 0;
    Array.prototype.forEach.call(outer.children, function (el) {
      // a chapter with a page wraps its link and caret in .m-sec__head, whose
      // height is the row's; a plain chapter's row is the button itself
      var b = el.querySelector('.m-sec__head') || el.querySelector('.m-sec__btn');
      var p = el.querySelector('.m-sec__panel');
      // + the section's own border: .m-sec has a top rule its row does not
      // measure, and five of them clipped the last chapter by a few pixels
      if (b) { h += b.offsetHeight + (el.offsetHeight - el.clientHeight); if (p && el.classList.contains('open')) h += itmPanelHeight(p); }
      else { h += el.offsetHeight; }
    });
    return h;
  }
  function regrow(node) {
    var sec = node.closest ? node.closest('.m-sec') : null;
    if (sec && sec.classList.contains('open')) {
      var p = sec.querySelector('.m-sec__panel');
      if (p) p.style.maxHeight = itmPanelHeight(p) + 'px';
    }
    var outer = node.closest ? node.closest('.m-acc__panel') : null;
    if (outer && outer.style.maxHeight && outer.style.maxHeight !== '0px') {
      outer.style.maxHeight = acctHeight(outer) + 'px';
    }
  }

  document.querySelectorAll('.m-sec').forEach(function (sec) {
    var btn = sec.querySelector('.m-sec__btn');
    var panel = sec.querySelector('.m-sec__panel');
    if (!btn || !panel) return;
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var open = sec.classList.toggle('open');
      if (btn.hasAttribute('aria-expanded')) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      panel.style.maxHeight = open ? itmPanelHeight(panel) + 'px' : '0';
      var outer = sec.closest('.m-acc__panel');
      if (outer) outer.style.maxHeight = acctHeight(outer) + 'px';
    });
  });

  /* A subsection's brand list. The caret is its own control -- tapping the
     label still navigates to the category. */
  document.querySelectorAll('.m-itm__btn').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var itm = btn.closest('.m-itm');
      var panel = itm.querySelector('.m-itm__panel');
      if (!panel) return;
      var open = itm.classList.toggle('open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      panel.style.maxHeight = open ? panel.scrollHeight + 'px' : '0';
      regrow(itm);
    });
  });

  /* ---- Mobile accordions ---- */
  document.querySelectorAll('.m-acc').forEach(function (acc) {
    var btn = acc.querySelector('.m-acc__btn');
    var panel = acc.querySelector('.m-acc__panel');
    btn.addEventListener('click', function () {
      var isOpen = acc.classList.toggle('open');
      panel.style.maxHeight = isOpen ? panel.scrollHeight + 'px' : '0';
    });
  });

  /* ---- Contact form: PDF upload (click + drag/drop) + submit ---- */
  (function () {
    var form = document.getElementById('contactForm');
    if (!form) return;
    var input = document.getElementById('cfFiles');
    var drop  = form.querySelector('.filedrop');
    var list  = document.getElementById('cfFileList');
    var msg   = document.getElementById('cfMsg');
    var files = [];
    // The same limits api/contact.php enforces - checked here first so nobody
    // waits for a 15 MB upload only to be told it is too big.
    var MAX = 10 * 1024 * 1024,        // per file, as the drop zone says
        MAX_FILES = 5,
        MAX_TOTAL = 15 * 1024 * 1024;

    /* Honeypot: a field people never see or reach with Tab. Bots that fill in
       every box fill this one too, and the server quietly drops their message. */
    var hp = document.createElement('div');
    hp.setAttribute('aria-hidden', 'true');
    hp.style.cssText = 'position:absolute;left:-10000px;top:auto;width:1px;height:1px;overflow:hidden';
    hp.innerHTML = '<label>Website <input type="text" name="website" tabindex="-1" autocomplete="off"></label>';
    form.appendChild(hp);

    function fmtSize(b) {
      if (b < 1024) return b + ' B';
      if (b < 1048576) return Math.round(b / 1024) + ' KB';
      return (b / 1048576).toFixed(1) + ' MB';
    }
    function flash(text, type) { msg.hidden = false; msg.textContent = text; msg.className = 'form-msg ' + type; }
    function clearMsg() { msg.hidden = true; msg.textContent = ''; msg.className = 'form-msg'; }

    function render() {
      list.innerHTML = '';
      files.forEach(function (f, i) {
        var chip = document.createElement('div');
        chip.className = 'filechip';
        chip.innerHTML =
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg>' +
          '<span class="name"></span><span class="size"></span>' +
          '<button type="button" aria-label="' + T.remove + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg></button>';
        chip.querySelector('.name').textContent = f.name;
        chip.querySelector('.size').textContent = fmtSize(f.size);
        chip.querySelector('button').addEventListener('click', function () {
          files.splice(i, 1); render();
        });
        list.appendChild(chip);
      });
    }

    function addFiles(fileList) {
      var rejected = false;
      Array.prototype.forEach.call(fileList, function (f) {
        var isPdf = f.type === 'application/pdf' || /\.pdf$/i.test(f.name);
        if (!isPdf) { rejected = true; return; }
        if (f.size > MAX) { flash(T.big.replace('{n}', f.name), 'err'); return; }
        if (files.some(function (x) { return x.name === f.name && x.size === f.size; })) return;
        var total = files.reduce(function (s, x) { return s + x.size; }, 0);
        if (files.length >= MAX_FILES || total + f.size > MAX_TOTAL) { flash(T.tooMany, 'err'); return; }
        files.push(f);
      });
      if (rejected) flash(T.file, 'err');
      else if (files.length) clearMsg();
      render();
    }

    input.addEventListener('change', function () { addFiles(input.files); input.value = ''; });

    ['dragenter', 'dragover'].forEach(function (ev) {
      drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('is-over'); });
    });
    ['dragleave', 'dragend', 'drop'].forEach(function (ev) {
      drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove('is-over'); });
    });
    drop.addEventListener('drop', function (e) {
      if (e.dataTransfer && e.dataTransfer.files) addFiles(e.dataTransfer.files);
    });

    /* ---- Delivery ---- to api/contact.php (see FORMS at the top of this file).
       It answers {ok:true} or {ok:false, error:"<code>"}; each code the visitor
       can do something about has its own message, the rest get "fail". */
    var en = (document.documentElement.lang || 'ka').indexOf('en') === 0;
    var T = en ? {
      sending: 'Sending…',
      ok:      'Thank you. Your request has been sent - we will be in touch shortly.',
      fail:    'The message could not be sent. Please email info@biomi.ge or call +995 322 15 11 15.',
      unwired: 'The form is not connected yet. Please email info@biomi.ge or call +995 322 15 11 15.',
      invalid: 'Please check the fields and try again.',
      file:    'Only PDF files can be attached.',
      tooMany: 'Attach up to 5 PDF files, 15 MB together at most.',
      big:     '“{n}” is too large (10 MB per file at most).',
      remove:  'Remove',
      rate:    'Too many messages were sent from this connection. Please try again in 15 minutes.',
      // field checks, shown in the form's own bubble
      required: 'Please fill in this field.',
      name:     'Please enter your first and last name.',
      email:    'Please enter a valid email address, e.g. name@example.com.',
      phone:    'Please enter a valid phone number.',
      privacy:  'Please agree to the privacy policy to send your request.',
      processing: 'Please agree to the processing of your personal data to send your request.',
      consent:  'Please tick both required consents to send your request.'
    } : {
      sending: 'იგზავნება…',
      ok:      'მადლობა! თქვენი მოთხოვნა გაიგზავნა - ჩვენ მალე დაგიკავშირდებით.',
      fail:    'შეტყობინება ვერ გაიგზავნა. მოგვწერეთ info@biomi.ge ან დაგვირეკეთ +995 322 15 11 15.',
      unwired: 'ფორმა ჯერ არ არის დაკავშირებული. მოგვწერეთ info@biomi.ge ან დაგვირეკეთ +995 322 15 11 15.',
      invalid: 'გთხოვთ, შეამოწმეთ ველები და სცადეთ ხელახლა.',
      file:    'მხოლოდ PDF ფაილების ატვირთვაა შესაძლებელი.',
      tooMany: 'შეგიძლიათ მიამაგროთ მაქსიმუმ 5 PDF ფაილი, ჯამში 15MB-მდე.',
      big:     '„{n}“ ძალიან დიდია (მაქს. 10MB თითო ფაილზე).',
      remove:  'წაშლა',
      rate:    'ამ კავშირიდან ძალიან ბევრი შეტყობინება გაიგზავნა. სცადეთ 15 წუთის შემდეგ.',
      required: 'გთხოვთ, შეავსეთ ეს ველი.',
      name:     'გთხოვთ, მიუთითეთ სახელი და გვარი.',
      email:    'გთხოვთ, მიუთითეთ სწორი ელ. ფოსტა, მაგ. name@example.com.',
      phone:    'გთხოვთ, მიუთითეთ სწორი ტელეფონის ნომერი.',
      privacy:  'მოთხოვნის გაგზავნისთვის საჭიროა კონფიდენციალურობის პოლიტიკასთან თანხმობა.',
      processing: 'მოთხოვნის გაგზავნისთვის საჭიროა თანხმობა პერსონალურ მონაცემთა დამუშავებაზე.',
      consent:  'მოთხოვნის გაგზავნისთვის საჭიროა ორივე სავალდებულო თანხმობა.'
    };
    // "consent" comes back from api/contact.php only if the ticks were skipped
    // around the page's own check, so it names both required boxes
    var ERR_MSG = { invalid: T.invalid, consent: T.consent, file: T.file, too_large: T.tooMany, rate: T.rate };
    var submitBtn = form.querySelector('button[type="submit"]');

    /* ---- Checking the fields ----
       The browser's own pop-up is grey, looks different in every browser and is
       worded in the BROWSER's language, not the page's - an English Chrome says
       "Please check this box" on the Georgian page. So the form checks itself
       and points at the first problem with its own bubble, in the page's
       language. The rules match api/contact.php, which checks everything again. */
    function problem(el) {
      var v = (el.value || '').trim();
      // two required ticks since 2026-09-18 (privacy policy, personal data): the
      // bubble names the one that was missed
      if (el.type === 'checkbox') return el.required && !el.checked ? (el.name === 'processing' ? T.processing : T.privacy) : '';
      if (el.validity && el.validity.customError) return el.validationMessage;   // the word limit's own message
      if (el.required && !v) return T.required;
      if (el.name === 'fullname' && v.length < 2) return T.name;
      if (el.type === 'email' && v && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v)) return T.email;
      if (el.type === 'tel' && v) {
        var n = v.replace(/\D/g, '').length;
        if (n < 7 || n > 15 || !/^[\d\s()+\-.]+$/.test(v)) return T.phone;
      }
      return '';
    }
    var tip = null;
    function clearTip() {
      if (!tip) return;
      tip.field.classList.remove('is-invalid');
      tip.field.removeAttribute('aria-invalid');
      tip.field.removeAttribute('aria-describedby');
      tip.el.remove();
      tip = null;
    }
    function showTip(el, text) {
      clearTip();
      // a <span>, not a <div>: for the checkbox it sits inside a <label>
      var b = document.createElement('span');
      b.className = 'form-tip' + (el.type === 'checkbox' ? ' form-tip--above' : '');
      b.id = 'cfTip';
      b.setAttribute('role', 'alert');
      b.innerHTML = '<span class="form-tip__icon" aria-hidden="true">!</span><span class="form-tip__text"></span>';
      b.querySelector('.form-tip__text').textContent = text;
      (el.closest('.consent') || el.closest('.field') || el.parentNode).appendChild(b);
      el.classList.add('is-invalid');
      el.setAttribute('aria-invalid', 'true');
      el.setAttribute('aria-describedby', 'cfTip');
      tip = { el: b, field: el };
      requestAnimationFrame(function () { b.classList.add('is-in'); });
      // window.scrollTo, not scrollIntoView: sections clip their overflow, and
      // scrollIntoView scrolls the clipped box instead of the page
      var r = el.getBoundingClientRect();
      if (r.top < 110 || r.bottom > window.innerHeight - 90) {
        window.scrollTo({ top: window.scrollY + r.top - window.innerHeight / 3, behavior: 'smooth' });
      }
      el.focus({ preventScroll: true });
    }
    function validate() {
      var els = form.querySelectorAll('input:not([type=file]):not([name=website]), textarea');
      for (var i = 0; i < els.length; i++) {
        var p = problem(els[i]);
        if (p) { showTip(els[i], p); return false; }
      }
      return true;
    }
    // fixing the field (or ticking the box) takes the bubble away
    ['input', 'change'].forEach(function (ev) {
      form.addEventListener(ev, function (e) { if (tip && e.target === tip.field) clearTip(); });
    });

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      clearMsg();                 // an earlier "thank you" must not sit above a new problem
      if (!validate()) return;
      if (!FORMS.LIVE) {
        flash(T.unwired, 'err');
        if (window.console) console.warn('contact form: only works on biomi.ge, nothing was sent');
        return;
      }

      var data = new FormData(form);
      // the file input is `hidden` and the list is held in JS, so the files have
      // to be attached from that array rather than left to FormData
      data.delete('files');
      files.forEach(function (f) { data.append('files[]', f, f.name); });
      data.append('lang', en ? 'en' : 'ka');
      data.append('page', location.href);

      submitBtn.disabled = true;
      flash(T.sending, 'ok');
      fetch(FORMS.ENDPOINT, { method: 'POST', body: data })
        .then(function (r) {
          return r.json().catch(function () { return { ok: false, error: 'http ' + r.status }; });
        })
        .then(function (res) {
          if (!res || !res.ok) {
            var err = new Error('contact.php said: ' + ((res && res.error) || 'nothing'));
            err.code = res && res.error;
            throw err;
          }
          // GA's standard name for an enquiry, so it can be marked as a key event
          track('generate_lead', { form_name: 'contact', attachments: files.length });
          flash(T.ok, 'ok');
          form.reset(); files = []; render();
          form.dispatchEvent(new Event('reset'));
        })
        .catch(function (err) {
          // on the test site the reason is shown too, so a failed test can be
          // reported from a screenshot without opening the browser console
          var why = /^test\./i.test(location.hostname) ? ' [' + (err.code || err.message) + ']' : '';
          flash((ERR_MSG[err.code] || T.fail) + why, 'err');
          if (window.console) console.error('contact form:', err);
        })
        .then(function () { submitBtn.disabled = false; });
    });
  })();

  /* ---- Word limit on the free-text brief ----
     HTML can cap characters but not words, so the count is done here. The text
     is never truncated -- typing past the limit turns the counter red and marks
     the field invalid, which the form's own checkValidity() already blocks on,
     so the customer keeps what they wrote and can trim it themselves. */
  document.querySelectorAll('textarea[data-maxwords]').forEach(function (ta) {
    var max = parseInt(ta.getAttribute('data-maxwords'), 10) || 150;
    var out = document.querySelector('.field__count[data-for="' + ta.id + '"]');
    if (!out) return;
    // the label's own text says what the unit is, so reuse it rather than
    // hard-coding "words" in two languages here
    var unit = (out.textContent.split('/')[1] || '').replace(/[\d\s]/g, '');
    var over = (document.documentElement.lang || 'ka').indexOf('en') === 0
      ? 'Please shorten this to ' + max + ' words or fewer.'
      : 'გთხოვთ, შეამოკლოთ ' + max + ' სიტყვამდე.';

    function sync() {
      var words = ta.value.trim() ? ta.value.trim().split(/\s+/).length : 0;
      out.textContent = words + ' / ' + max + ' ' + unit;
      out.classList.toggle('is-over', words > max);
      ta.setCustomValidity(words > max ? over : '');
    }
    ta.addEventListener('input', sync);
    if (ta.form) ta.form.addEventListener('reset', function () { setTimeout(sync, 0); });
    sync();
  });

  /* ---- Services ring: click a category -> rotate it to 3 o'clock, reveal detail ---- */
  document.querySelectorAll('.ring-wrap').forEach(function (wrap) {
    var ring = wrap.querySelector('.ring');
    var nodes = ring.querySelectorAll('.ring__node');
    var detail = wrap.querySelector('.ring__detail');
    var dTitle = detail.querySelector('.ring__detail-title');
    var dDesc = detail.querySelector('.ring__detail-desc');
    var dLink = detail.querySelector('.ring__detail-link');

    /* The tap hint hides while a step is open (.is-focused) and comes back when
       the wheel closes. It used to be dismissed for good on the first touch,
       so after one look the wheel never showed it again until a reload.
       Stacked under the ring on narrow screens, the panel folds back to the
       height it has empty when it closes (see .ring__detail in the CSS), so
       that height is measured now, before anything has filled it. */
    detail.style.setProperty('--rest-h', detail.offsetHeight + 'px');

    /* Where a node sits on the ring, in the same degrees the markup places it. */
    function angleOf(n) { return parseFloat(n.style.getPropertyValue('--a')) || 0; }

    var at = -1;    // which step is up; -1 is nothing open yet
    var rot = 0;    /* the ring's rotation, kept running rather than normalised
                       into (-180,180]: normalising is what sends the wheel most
                       of the way round backwards on the wrap from the last step
                       to the first, and this way it only ever turns one step,
                       the same direction, every time. */

    function unfocus() {
      wrap.classList.remove('is-focused');
      ring.classList.remove('has-active');
      nodes.forEach(function (x) { x.classList.remove('is-active'); });
      ring.style.setProperty('--rot', '0deg');
      at = -1; rot = 0;
    }
    function focusNode(n, rotation) {
      nodes.forEach(function (x) { x.classList.remove('is-active'); });
      n.classList.add('is-active');
      ring.classList.add('has-active');
      wrap.classList.add('is-focused');
      ring.style.setProperty('--rot', rotation + 'deg');
      dTitle.textContent = n.getAttribute('data-title') || '';
      dDesc.textContent = n.getAttribute('data-desc') || '';
      // every step offers a way through to the services page
      if (dLink) {
        var href = n.getAttribute('data-href');
        dLink.hidden = !href;
        if (href) {
          dLink.href = href;
          dLink.textContent = n.getAttribute('data-cta') || '';
        }
      }
    }
    /* One click, one step round. Clicking a node used to open that node, which
       let a reader take the seven steps of a cycle in whatever order they
       happened to click -- including backwards, which a cycle does not run.
       The wheel walks them in order now: whichever node is clicked, the step
       after the current one comes to 3 o'clock. The hub still closes the
       panel, and closing sets it back to the beginning.
       The turn is measured off the two nodes rather than assumed to be 360/7,
       so nothing here needs revisiting if a step is ever added or dropped. */
    function advance() {
      if (at < 0) {
        at = 0;
        rot = 90 - angleOf(nodes[0]);   // bring the first step to 3 o'clock
      } else {
        var next = (at + 1) % nodes.length;
        var d = angleOf(nodes[next]) - angleOf(nodes[at]);
        if (d <= 0) d += 360;           // the wrap from the last step to the first
        rot -= d;
        at = next;
      }
      focusNode(nodes[at], rot);
    }
    nodes.forEach(function (n) {
      n.addEventListener('click', function (e) {
        e.stopPropagation();
        advance();
      });
    });
    var center = ring.querySelector('.ring__center');
    if (center) center.addEventListener('click', unfocus);
    wrap._unfocus = unfocus;
  });
  document.addEventListener('click', function (e) {
    if (e.target.closest('.ring-wrap')) return;
    document.querySelectorAll('.ring-wrap.is-focused').forEach(function (w) {
      if (w._unfocus) w._unfocus();
    });
  });

  /* ---- Product card chips that link to their own page ---- */
  document.querySelectorAll('.prod li[data-href]').forEach(function (chip) {
    function go(e) {
      e.preventDefault();     // don't follow the parent card's link
      e.stopPropagation();
      window.location.href = chip.getAttribute('data-href');
    }
    chip.addEventListener('click', go);
    chip.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') go(e);
    });
  });

  /* ---- News share buttons ---- */
  document.querySelectorAll('.news__share').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      e.preventDefault(); e.stopPropagation();
      var card = btn.closest('.news');
      var h3 = card && card.querySelector('h3');
      // headings are converted to Mtavruli for display; aria-label keeps the
      // readable Mkhedruli original, which is what we want to share.
      var title = h3 ? (h3.getAttribute('aria-label') || h3.textContent).trim() : document.title;
      /* A card shares its own article, not the page the card happens to sit on:
         this used location.href, so sharing from the homepage sent the homepage.
         The button at the top of an article page is in no card and shares that
         page (without any #fragment). */
      var link = card && card.querySelector('h3 a[href], a.link-more[href]');
      var url = link ? new URL(link.getAttribute('href'), location.href).href
                     : location.href.split('#')[0];
      if (navigator.share) {
        navigator.share({ title: title, text: title, url: url }).catch(function () {});
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(url).then(function () {
          btn.classList.add('copied');
          setTimeout(function () { btn.classList.remove('copied'); }, 1300);
        }).catch(function () {});
      }
    });
  });

  /* ---- Project card photos, loaded as their grid comes near ----
     The CSS gives .proj__img its background only under .is-near. The whole grid
     is marked at once, not card by card: on phones it is a sideways-scrolling
     rail, and cards clipped off to the right would otherwise come up blank as
     they are swiped in. */
  var projGrids = document.querySelectorAll('.proj-grid, .proj-gallery');
  if ('IntersectionObserver' in window) {
    var nearIo = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('is-near'); nearIo.unobserve(entry.target); }
      });
    }, { rootMargin: '600px 0px' });
    projGrids.forEach(function (el) { nearIo.observe(el); });
  } else {
    projGrids.forEach(function (el) { el.classList.add('is-near'); });
  }

  /* ---- Reveal on scroll ---- */
  var reveals = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('in'); io.unobserve(entry.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---- Skip link ----
     The first stop for someone moving through the page with the keyboard: past
     the header and its menu, straight to the page's own content. Off-screen until
     it has focus. Added here, before the anchor handler below picks up every
     "#" link, so that handler does the scrolling and this one only moves focus --
     without the focus move, the next Tab would land back in the menu. The
     target is whatever follows the header, so every page gets it unedited. */
  (function () {
    var header = document.getElementById('header');
    var target = header && header.nextElementSibling;
    if (!target) return;
    if (!target.id) target.id = 'content';
    target.setAttribute('tabindex', '-1');
    target.classList.add('skip-target');
    var en = (document.documentElement.lang || 'ka').indexOf('en') === 0;
    var a = document.createElement('a');
    a.className = 'skip-link';
    a.href = '#' + target.id;
    a.textContent = en ? 'Skip to content' : 'მთავარ კონტენტზე გადასვლა';
    a.addEventListener('click', function () {
      try { target.focus({ preventScroll: true }); } catch (err) { target.focus(); }
    });
    document.body.insertBefore(a, document.body.firstChild);
  })();

  /* ---- Smooth anchor scroll with header offset ---- */
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var id = a.getAttribute('href');
      if (id.length < 2) return;
      var target = document.querySelector(id);
      if (!target) return;
      e.preventDefault();
      var top = target.getBoundingClientRect().top + window.scrollY - 70;
      window.scrollTo({ top: top, behavior: 'smooth' });
    });
  });
})();

/* ============ Product redesign: listing filter · gallery · tabs · chips ============ */
(function () {
  'use strict';
  var list = document.querySelector('[data-plist]');
  if (list) {
    /* .duct as well as .pcard: the ducting parts are made to order and have no
       page of their own, so they are figures rather than links, but they filter
       exactly like everything else. Everything below reads data- attributes and
       never the tag, so widening the selector is the whole change. */
    var cards = Array.prototype.slice.call(
      list.querySelectorAll('.pcard[data-cat], .duct[data-name]'));
    var tabs = list.querySelectorAll('.cattabs button');
    var checks = Array.prototype.slice.call(list.querySelectorAll('.pfilter input'));
    var search = list.querySelector('.pfilter__search input');
    var empty = list.querySelector('.pgrid__empty');
    var curCat = 'all';
    /* A box can be scoped to one section of a chapter page (data-scope, e.g.
       "boilers"): the nested filters under a category tick. It then narrows only
       that section's cards and leaves the rest alone -- boilers, burners and
       water heaters all file something different under data-type (origin,
       fuel, tank), so an unscoped "type" would hide the other two sections. */
    function apply() {
      var q = (search && search.value || '').toLowerCase().trim();
      var active = {};
      checks.forEach(function (c) {
        if (!c.checked) return;
        var scope = c.getAttribute('data-scope') || '';
        var key = scope + '|' + c.name;
        (active[key] = active[key] || { name: c.name, scope: scope, vals: [] }).vals.push(c.value);
      });
      var shown = 0;
      cards.forEach(function (card) {
        var okCat = curCat === 'all' || card.getAttribute('data-cat') === curCat;
        var okSearch = !q || (card.getAttribute('data-name') || '').toLowerCase().indexOf(q) >= 0;
        var okFilter = Object.keys(active).every(function (key) {
          var a = active[key];
          if (a.scope && card.getAttribute('data-sec') !== a.scope) return true;
          var vals = (card.getAttribute('data-' + a.name) || '').split(',');
          return a.vals.some(function (v) { return vals.indexOf(v) >= 0; });
        });
        var ok = okCat && okSearch && okFilter;
        card.style.display = ok ? '' : 'none';
        if (ok) shown++;
      });
      if (empty) empty.style.display = shown ? 'none' : '';
    }
    tabs.forEach(function (t) { t.addEventListener('click', function () { tabs.forEach(function (x) { x.classList.remove('active'); }); t.classList.add('active'); curCat = t.getAttribute('data-cat'); apply(); }); });
    checks.forEach(function (c) { c.addEventListener('change', apply); });
    if (search) search.addEventListener('input', apply);
    var clr = list.querySelector('[data-clear]');
    if (clr) clr.addEventListener('click', function () {
      checks.forEach(function (c) { c.checked = false; });
      if (search) search.value = '';
      // the category tabs live inside the filter panel now, so "clear" has to
      // reset them too or the panel says empty while a category is still on
      tabs.forEach(function (t) { t.classList.toggle('active', t.getAttribute('data-cat') === 'all'); });
      curCat = 'all';
      apply();
    });
    list.querySelectorAll('.pfilter__group h4').forEach(function (h) { h.addEventListener('click', function () { h.parentElement.classList.toggle('closed'); }); });

    /* ---- The "!" beside a series name ----
       Hovering shows the explanation (CSS, from data-tip). A click or tap pins
       it open -- the only way on a touchscreen -- and a click anywhere else, or
       Esc, closes it. It sits inside the label, so the click must not reach the
       checkbox. */
    var infos = Array.prototype.slice.call(list.querySelectorAll('.pfilter__info'));
    function closeInfos(except) {
      infos.forEach(function (x) {
        if (x !== except) { x.classList.remove('is-open'); x.setAttribute('aria-expanded', 'false'); }
      });
    }
    infos.forEach(function (b) {
      b.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        closeInfos(b);
        var open = b.classList.toggle('is-open');
        b.setAttribute('aria-expanded', open ? 'true' : 'false');
      });
    });
    if (infos.length) {
      document.addEventListener('click', function () { closeInfos(null); });
      document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeInfos(null); });
    }

    /* ---- A category's own filters, dropping down under its box ----
       On a chapter page (heating.html ...) each category is followed by a
       .pfilter__sub holding that category's filters, scoped to it (see apply).
       Ticking the category opens them; unticking closes them and clears what
       was ticked inside, so a hidden box never keeps narrowing the list. */
    var subs = Array.prototype.slice.call(list.querySelectorAll('.pfilter__sub[data-for]'));
    function ownerOf(sub) {
      var prev = sub.previousElementSibling;
      return prev ? prev.querySelector('input[value="' + sub.getAttribute('data-for') + '"]') : null;
    }
    function syncSubs() {
      subs.forEach(function (sub) {
        var owner = ownerOf(sub);
        var open = !!(owner && owner.checked);
        if (open === !sub.hidden) return;
        sub.hidden = !open;
        if (!open) {
          sub.querySelectorAll('input:checked').forEach(function (c) {
            c.checked = false;
            c.dispatchEvent(new Event('change'));   // re-filter and recount
          });
        }
      });
    }
    subs.forEach(function (sub) {
      var owner = ownerOf(sub);
      if (owner) owner.addEventListener('change', syncSubs);
    });
    if (clr) clr.addEventListener('click', syncSubs);

    /* ---- Pre-tick filter boxes from the URL ----
       There are no brand landing pages any more: the product menu points
       straight at the category listing with ?brand=vortice, which is the same
       page with one box already ticked. Matching is by checkbox name, not a
       hardcoded list of brands, so ?brand=riello&type=wall works too and any
       filter group added later is supported without touching this. */
    var qs = window.location.search.replace(/^\?/, '');
    if (qs) {
      var want = {};
      qs.split('&').forEach(function (pair) {
        var eq = pair.indexOf('=');
        if (eq < 1) return;
        var k = decodeURIComponent(pair.slice(0, eq));
        decodeURIComponent(pair.slice(eq + 1).replace(/\+/g, ' ')).split(',').forEach(function (v) {
          (want[k] = want[k] || []).push(v.trim().toLowerCase());
        });
      });
      checks.forEach(function (c) {
        if (want[c.name] && want[c.name].indexOf(c.value.toLowerCase()) >= 0) c.checked = true;
      });
    }
    // a category ticked from the URL (?sec=boilers) opens its filters too
    syncSubs();

    /* ---- Phone: collapse the filter behind a toggle ----
       Stacked on a phone the sidebar puts a wall of checkboxes above the grid.
       Everything except the search box moves into .pfilter__body, which CSS
       hides below 760px until the injected toggle opens it. Built here rather
       than in markup so every hub page (and any future one) gets it. */
    var panel = list.querySelector('.pfilter');
    if (panel && !panel.querySelector('.pfilter__body')) {
      var head = panel.querySelector('.pfilter__head');
      var body = document.createElement('div');
      body.className = 'pfilter__body';
      var move = [];
      for (var n = head; n; n = n.nextElementSibling) { move.push(n); }
      move.forEach(function (el) { body.appendChild(el); });
      panel.appendChild(body);

      var label = (head && head.querySelector('span') && head.querySelector('span').textContent.trim()) || 'Filter';
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'pfilter__toggle';
      btn.setAttribute('aria-expanded', 'false');
      btn.innerHTML = '<span>' + label + '</span><span class="pfilter__count"></span>' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-left:auto"><path d="m6 9 6 6 6-6"/></svg>';
      panel.classList.add('is-collapsible');
      panel.insertBefore(btn, body);

      btn.addEventListener('click', function () {
        var open = panel.classList.toggle('is-open');
        btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      });

      var badge = btn.querySelector('.pfilter__count');
      var count = function () {
        var n = checks.filter(function (c) { return c.checked; }).length;
        badge.textContent = n || '';
        badge.classList.toggle('on', n > 0);
      };
      checks.forEach(function (c) { c.addEventListener('change', count); });
      if (clr) clr.addEventListener('click', count);
      count();
    }

    apply();
  }

  document.querySelectorAll('.pgal').forEach(function (gal) {
    var main = gal.querySelector('.pgal__main img');
    var wrap = gal.querySelector('.pgal__thumbs');
    if (!main || !wrap || !wrap.querySelector('img')) return;
    var i = 0;
    /* Read the thumbs live rather than caching them: the capacity chips on some
       product pages swap the whole set when you pick a different model. */
    function thumbs() { return Array.prototype.slice.call(wrap.querySelectorAll('img')); }
    function show(n) {
      var t = thumbs();
      if (!t.length) return;
      i = (n + t.length) % t.length;
      main.src = t[i].getAttribute('data-full') || t[i].src;
      main.alt = t[i].alt;
      t.forEach(function (x, k) { x.classList.toggle('active', k === i); });
    }
    // delegated, so rebuilt thumbnails stay clickable without re-binding
    wrap.addEventListener('click', function (e) {
      var img = e.target && e.target.closest ? e.target.closest('img') : null;
      if (!img || !wrap.contains(img)) return;
      show(thumbs().indexOf(img));
    });
    gal.__showSlide = show;   // used by the model switcher after it swaps the set
    var p = gal.querySelector('.pgal__prev'), nx = gal.querySelector('.pgal__next');
    if (p) p.addEventListener('click', function () { show(i - 1); });
    if (nx) nx.addEventListener('click', function () { show(i + 1); });

    /* Click (or Enter/Space on) the big image to view the gallery full-screen.
       Reuses the shared lightbox, so arrows / Esc / backdrop-close come free, and
       on close the gallery jumps to whichever slide you ended on. The .pgal arrows
       are siblings of this <img>, so they never trigger it. */
    if (document.querySelector('.lightbox')) {   // lightbox module initialised
      main.style.cursor = 'zoom-in';
      main.setAttribute('role', 'button');
      main.setAttribute('tabindex', '0');
      main.setAttribute('aria-label', main.getAttribute('data-zoom-label') ||
        ((document.documentElement.lang || 'ka').slice(0, 2) === 'en' ? 'Enlarge image' : 'სურათის გადიდება'));
      var zoom = function () {
        document.dispatchEvent(new CustomEvent('biomi:lightbox', {
          detail: { items: thumbs(), index: i, onClose: show }
        }));
      };
      main.addEventListener('click', zoom);
      main.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') { e.preventDefault(); zoom(); }
      });
    }
    show(0);
  });

  /* ---- Accessory list: folded away until asked for ----
     The grid ships with [hidden] so it stays collapsed even before this runs,
     and the label swaps between show/hide. The count is baked into the button
     text at build time, so only the verb changes here. */
  document.querySelectorAll('.acc-toggle').forEach(function (btn) {
    var grid = btn.nextElementSibling;
    if (!grid || !grid.classList.contains('acc-grid')) return;
    var en = (document.documentElement.lang || 'ka').slice(0, 2) === 'en';
    var shown = btn.textContent.trim();
    var hidden = en ? shown.replace('Show', 'Hide') : shown.replace('ნახვა', 'დამალვა');
    var icon = btn.querySelector('svg');
    btn.addEventListener('click', function () {
      var open = grid.hasAttribute('hidden');
      if (open) { grid.removeAttribute('hidden'); } else { grid.setAttribute('hidden', ''); }
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      btn.textContent = open ? hidden : shown;
      if (icon) btn.appendChild(icon);   // textContent wipes it; put the chevron back
    });
  });

  document.querySelectorAll('.ptabs').forEach(function (tabs) {
    var btns = tabs.querySelectorAll('.ptabs__nav button');
    var panels = tabs.querySelectorAll('.ptabs__panel');
    btns.forEach(function (b) {
      b.addEventListener('click', function () {
        var k = b.getAttribute('data-tab');
        btns.forEach(function (x) { x.classList.toggle('active', x === b); });
        panels.forEach(function (pn) { pn.classList.toggle('active', pn.getAttribute('data-panel') === k); });
      });
    });
  });

  /* ---- Capacity chips ----
     Plain chipsets just move the .active highlight. A chipset marked
     [data-modelswitch] additionally drives the page: picking a capacity is
     picking a model, so it swaps the model code, the gallery images, the
     matching spec-table cells, and the port-count chips. [data-imgswitch] is
     the lighter cousin -- it only swaps the gallery, for choices like a
     finish colour that leave every spec untouched. Everything either one
     needs travels on the chip itself, so pages opt in purely through markup. */
  document.querySelectorAll('.chipset').forEach(function (set) {
    var chips = Array.prototype.slice.call(set.querySelectorAll('.chip'));
    var isSwitch = set.hasAttribute('data-modelswitch');
    var isImgSwitch = set.hasAttribute('data-imgswitch');
    var base = set.getAttribute('data-imgbase') || '';
    var detail = set.closest('.pdetail') || document;
    var gal = detail.querySelector('.pgal');
    var wrap = gal && gal.querySelector('.pgal__thumbs');

    // rebuild the thumbnail strip from this chip's set, then reset to its first shot
    function applyImages(c) {
      var imgs = (c.getAttribute('data-imgs') || '').split(',').filter(Boolean);
      if (!wrap || !imgs.length) return;
      var label = c.getAttribute('data-alt') || c.getAttribute('data-model') || '';
      wrap.innerHTML = imgs.map(function (src, k) {
        return '<img src="' + base + src.trim() + '" alt="' + label +
               (k ? ' - ' + (k + 1) : '') + '">';
      }).join('');
      if (gal.__showSlide) gal.__showSlide(0);
    }

    function applyModel(c) {
      var model = c.getAttribute('data-model');
      if (!model) return;

      var codeEl = detail.querySelector('.pbuy__model');
      if (codeEl) codeEl.textContent = model;

      applyImages(c);

      // Spec rows are tagged data-spec="<key>" and the chip carries the value
      // as data-<key>. Which keys exist is the page's business -- an air
      // conditioner switches cool/heat, a fan switches airflow and dB -- so
      // they are read off the chip rather than hardcoded. Only "model" is
      // constant, and data-imgs/data-alt belong to the gallery, not the table.
      var keys = ['model'];
      Array.prototype.forEach.call(c.attributes, function (a) {
        var k = a.name.indexOf('data-') === 0 ? a.name.slice(5) : '';
        if (k && k !== 'imgs' && k !== 'alt' && keys.indexOf(k) < 0) keys.push(k);
      });
      keys.forEach(function (key) {
        var v = key === 'model' ? model : c.getAttribute('data-' + key);
        var cell = document.querySelector('[data-spec="' + key + '"]');
        if (cell && v) cell.textContent = v;
      });

      // keep the port-count chips in step with the chosen model
      var ports = c.getAttribute('data-ports');
      var portSet = document.querySelector('[data-portset]');
      if (ports && portSet) {
        portSet.querySelectorAll('.chip').forEach(function (pc) {
          pc.classList.toggle('active', pc.textContent.trim() === ports);
        });
      }
    }

    chips.forEach(function (c) {
      c.addEventListener('click', function () {
        chips.forEach(function (x) { x.classList.remove('active'); });
        c.classList.add('active');
        if (isSwitch) applyModel(c);
        else if (isImgSwitch) applyImages(c);
      });
    });
  });

  /* ---- Finishes: a colour row that belongs to one model chip ----
     ME Punto Evo sells one model in several finishes, each with its own article
     code, so the swatches ([data-colorset]) are model switches in their own right.
     They only apply to the chip marked data-colors: picking another model hides
     the row, and coming back to that chip shows it again and re-applies the
     finish last chosen -- rose gold until someone picks another. Registered
     after the chip handlers above, so the swatch wins over the chip it follows. */
  document.querySelectorAll('.chipset[data-colorset]').forEach(function (cs) {
    var buy = cs.closest('.pbuy') || document;
    var label = cs.previousElementSibling && cs.previousElementSibling.hasAttribute('data-colorlabel') ? cs.previousElementSibling : null;
    var models = buy.querySelector('.chipset[data-modelswitch]:not([data-colorset])');
    if (!models) return;
    function sync(chip) {
      var has = !!(chip && chip.hasAttribute('data-colors'));
      cs.hidden = !has;
      if (label) label.hidden = !has;
      return has;
    }
    models.querySelectorAll('.chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        if (sync(chip)) {
          var pick = cs.querySelector('.chip.active') || cs.querySelector('.chip');
          if (pick) pick.click();
        }
      });
    });
    sync(models.querySelector('.chip.active'));
  });
})();
