/* ბიომი — interactions */
(function () {
  'use strict';

  /* ---- Georgian caps (Mtavruli) for nav + section titles ---- */
  /* CSS text-transform:uppercase does nothing for Georgian, so convert Mkhedruli
     text nodes to Mtavruli (U+10D0–U+10FF -> +0xBC0); keep readable aria-label. */
  (function () {
    function toMtavruli(s) {
      return s.replace(/[ა-ჿ]/g, function (c) {
        return String.fromCodePoint(c.codePointAt(0) + 0xBC0);
      });
    }
    var sel = '.nav__link, .section__head h2, .about__text h2, .contact__intro h2';
    document.querySelectorAll(sel).forEach(function (el) {
      if (el.dataset.caps) return;
      el.dataset.caps = '1';
      if (!el.getAttribute('aria-label')) el.setAttribute('aria-label', el.textContent.trim());
      var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
      var nodes = [], n;
      while ((n = walker.nextNode())) nodes.push(n);
      nodes.forEach(function (t) { t.nodeValue = toMtavruli(t.nodeValue); });
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
      cap.appendChild(ig);   // Instagram
      cap.appendChild(yt);   // YouTube
      fab.insertBefore(cap, fab.firstChild);
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

  /* ---- Nested brand submenu inside products dropdown (VRF/VRV) ---- */
  document.querySelectorAll('.prod-sub').forEach(function (sub) {
    var btn = sub.querySelector('.prod-sub__btn');
    var panel = sub.querySelector('.prod-sub__panel');
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var chap = sub.closest('.prod-menu__panel');
      var chapH = chap ? chap.scrollHeight : 0;   // current height (sub in its old state)
      var subH = panel.scrollHeight;              // sub content height
      var open = sub.classList.toggle('open');
      panel.style.maxHeight = open ? subH + 'px' : '0';
      // grow/shrink the enclosing chapter panel so nothing gets clipped
      if (chap) chap.style.maxHeight = (chapH + (open ? subH : -subH)) + 'px';
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
        if (n.classList.contains('is-active')) unfocus();
        else focusNode(n);
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
      var title = h3 ? h3.textContent.trim() : document.title;
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
