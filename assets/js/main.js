/* ბიომი — interactions */
(function () {
  'use strict';

  /* ---- Georgian caps (Mtavruli) wherever CSS asks for uppercase ---- */
  /* CSS text-transform:uppercase handles Latin but does nothing for Georgian, so
     Mkhedruli text nodes are converted to Mtavruli (U+10D0–U+10FF -> +0xBC0).
     Rather than keep a hand-written selector list in sync with the stylesheet,
     this reads the computed style: anything CSS renders uppercase (headings,
     .eyebrow kickers, .news__cat chips, nav links, tags) gets Georgian caps too.
     Style a new element uppercase in CSS and it is covered automatically.
     aria-label keeps the readable Mkhedruli text for screen readers. The regex
     matches only Mkhedruli, so already-Mtavruli source and re-runs are no-ops. */
  (function () {
    // Mkhedruli (lowercase) OR Mtavruli (caps) -- some titles are authored in
    // Mtavruli already, and those still need the CSS transform switched off.
    var GEORGIAN = /[ა-ჿᲐ-Ჿ]/;
    function isUpper(el) {
      return el && el.nodeType === 1 && getComputedStyle(el).textTransform === 'uppercase';
    }
    document.querySelectorAll('*').forEach(function (el) {
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
    if (ph) fab.appendChild(ph);   // Phone — call CTA
    if (top) fab.appendChild(top); // Back to top
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

  /* ---- Hero: infinite auto-carousel; mouse-move direction steers it ---- */
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
      if (!reduce) { offset += speed * dir; wrap(); render(); }
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);

    // Move the mouse over the images to steer direction (no clicking)
    vp.addEventListener('pointermove', function (e) {
      if (lastX !== null) {
        var dx = e.clientX - lastX;
        if (dx > 1) dir = -1;        // mouse moves right -> images move right
        else if (dx < -1) dir = 1;   // mouse moves left  -> images move left
      }
      lastX = e.clientX;
    });
    vp.addEventListener('pointerleave', function () { lastX = null; dir = 1; }); // back to default
  })();

  /* ---- Language toggle (GEO/ENG pills) — placeholder until ENG is built ---- */
  document.querySelectorAll('.lang, .drawer__langs').forEach(function (group) {
    group.querySelectorAll('button').forEach(function (btn) {
      btn.addEventListener('click', function () {
        group.querySelectorAll('button').forEach(function (b) { b.classList.remove('is-active'); });
        btn.classList.add('is-active');
      });
    });
  });

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

  /* ---- Products dropdown: chapter accordion (one open at a time) ---- */
  document.querySelectorAll('.prod-menu').forEach(function (menu) {
    var chapters = menu.querySelectorAll('.prod-menu__chapter');
    chapters.forEach(function (ch) {
      var btn = ch.querySelector('.prod-menu__btn');
      var panel = ch.querySelector('.prod-menu__panel');
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var wasOpen = ch.classList.contains('open');
        chapters.forEach(function (o) {
          o.classList.remove('open');
          o.querySelector('.prod-menu__panel').style.maxHeight = '0';
        });
        if (!wasOpen) {
          ch.classList.add('open');
          panel.style.maxHeight = panel.scrollHeight + 'px';
        }
      });
    });
  });

  /* ---- Nested brand submenu inside products dropdown (VRF/VRV) ----
     The label itself is a plain link to the VRF/VRV page (matching the mobile
     menu), so only the chevron toggles the brand list open. */
  document.querySelectorAll('.prod-sub').forEach(function (sub) {
    var btn = sub.querySelector('.prod-sub__toggle');
    var panel = sub.querySelector('.prod-sub__panel');
    if (!btn || !panel) return;
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var chap = sub.closest('.prod-menu__panel');
      var chapH = chap ? chap.scrollHeight : 0;   // current height (sub in its old state)
      var subH = panel.scrollHeight;              // sub content height
      var open = sub.classList.toggle('open');
      panel.style.maxHeight = open ? subH + 'px' : '0';
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      // grow/shrink the enclosing chapter panel so nothing gets clipped
      if (chap) chap.style.maxHeight = (chapH + (open ? subH : -subH)) + 'px';
    });
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
      var parent = im.parentElement;
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
      '<img alt="">' +
      '<iframe class="lightbox__frame" style="display:none" allow="autoplay; encrypted-media; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>' +
      '<button class="lightbox__nav lightbox__next" type="button" aria-label="შემდეგი"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m9 6 6 6-6 6"/></svg></button>';
    document.body.appendChild(lb);
    var lbImg = lb.querySelector('img');
    var frame = lb.querySelector('.lightbox__frame');
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

    /* Open an arbitrary image list on request — detail: {items, index, onClose}.
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
    var MAX = 10 * 1024 * 1024; // 10MB

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
          '<button type="button" aria-label="წაშლა"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg></button>';
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
        if (f.size > MAX) { flash('„' + f.name + '“ ძალიან დიდია (მაქს. 10MB).', 'err'); return; }
        if (files.some(function (x) { return x.name === f.name && x.size === f.size; })) return;
        files.push(f);
      });
      if (rejected) flash('მხოლოდ PDF ფაილების ატვირთვაა შესაძლებელი.', 'err');
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

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if (!form.checkValidity()) { form.reportValidity(); return; }
      // NOTE: static site — wire this to a form backend (Formspree / Web3Forms) to
      // actually deliver the fields + attached files. Build a FormData from `files`.
      flash('მადლობა! თქვენი მოთხოვნა მიღებულია — ჩვენ მალე დაგიკავშირდებით.', 'ok');
      form.reset(); files = []; render();
    });
  })();

  /* ---- Services ring: click a category -> rotate it to 3 o'clock, reveal detail ---- */
  document.querySelectorAll('.ring-wrap').forEach(function (wrap) {
    var ring = wrap.querySelector('.ring');
    var nodes = ring.querySelectorAll('.ring__node');
    var detail = wrap.querySelector('.ring__detail');
    var dTitle = detail.querySelector('.ring__detail-title');
    var dDesc = detail.querySelector('.ring__detail-desc');

    // dismiss the tap-hint once the user interacts with the ring
    wrap.addEventListener('pointerdown', function () { wrap.classList.add('is-hinted'); }, { once: true });

    function unfocus() {
      wrap.classList.remove('is-focused');
      ring.classList.remove('has-active');
      nodes.forEach(function (x) { x.classList.remove('is-active'); });
      ring.style.setProperty('--rot', '0deg');
    }
    function focusNode(n) {
      nodes.forEach(function (x) { x.classList.remove('is-active'); });
      n.classList.add('is-active');
      ring.classList.add('has-active');
      wrap.classList.add('is-focused');
      var a = parseFloat(n.style.getPropertyValue('--a')) || 0;
      var target = 90 - a;                          // bring node to the 3 o'clock spot
      target = ((target % 360) + 540) % 360 - 180;  // take the shortest path
      ring.style.setProperty('--rot', target + 'deg');
      dTitle.textContent = n.getAttribute('data-title') || '';
      dDesc.textContent = n.getAttribute('data-desc') || '';
    }
    nodes.forEach(function (n) {
      n.addEventListener('click', function (e) {
        e.stopPropagation();
        focusNode(n);   // clicking a node always focuses it; only clicking off resets
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
      var url = location.href;
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
    var cards = Array.prototype.slice.call(list.querySelectorAll('.pcard[data-cat]'));
    var tabs = list.querySelectorAll('.cattabs button');
    var checks = Array.prototype.slice.call(list.querySelectorAll('.pfilter input'));
    var search = list.querySelector('.pfilter__search input');
    var empty = list.querySelector('.pgrid__empty');
    var curCat = 'all';
    function apply() {
      var q = (search && search.value || '').toLowerCase().trim();
      var active = {};
      checks.forEach(function (c) { if (c.checked) { (active[c.name] = active[c.name] || []).push(c.value); } });
      var shown = 0;
      cards.forEach(function (card) {
        var okCat = curCat === 'all' || card.getAttribute('data-cat') === curCat;
        var okSearch = !q || (card.getAttribute('data-name') || '').toLowerCase().indexOf(q) >= 0;
        var okFilter = Object.keys(active).every(function (name) {
          var vals = (card.getAttribute('data-' + name) || '').split(',');
          return active[name].some(function (v) { return vals.indexOf(v) >= 0; });
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
    if (clr) clr.addEventListener('click', function () { checks.forEach(function (c) { c.checked = false; }); if (search) search.value = ''; apply(); });
    list.querySelectorAll('.pfilter__group h4').forEach(function (h) { h.addEventListener('click', function () { h.parentElement.classList.toggle('closed'); }); });
    apply();
  }

  document.querySelectorAll('.pgal').forEach(function (gal) {
    var main = gal.querySelector('.pgal__main img');
    var thumbs = Array.prototype.slice.call(gal.querySelectorAll('.pgal__thumbs img'));
    if (!main || !thumbs.length) return;
    var i = 0;
    function show(n) {
      i = (n + thumbs.length) % thumbs.length;
      main.src = thumbs[i].getAttribute('data-full') || thumbs[i].src;
      main.alt = thumbs[i].alt;
      thumbs.forEach(function (t, k) { t.classList.toggle('active', k === i); });
    }
    thumbs.forEach(function (t, k) { t.addEventListener('click', function () { show(k); }); });
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
          detail: { items: thumbs, index: i, onClose: show }
        }));
      };
      main.addEventListener('click', zoom);
      main.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') { e.preventDefault(); zoom(); }
      });
    }
    show(0);
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

  document.querySelectorAll('.chipset').forEach(function (set) {
    var chips = set.querySelectorAll('.chip');
    chips.forEach(function (c) { c.addEventListener('click', function () { chips.forEach(function (x) { x.classList.remove('active'); }); c.classList.add('active'); }); });
  });
})();
