(function () {
  if (window.rdChem) return;
  var STYLES = {
    skeletal: { c: true },
    explicit: { c: true, h: true, o: { explicitMethyl: true } },
    color: { c: true },
    bw: { c: false },
    comic: { c: true, o: { comicMode: true } },
    compact: { c: true, o: { bondLineWidth: 1, baseFontSize: 0.45, padding: 0.04 } },
    bold: { c: false, o: { bondLineWidth: 3 } }
  };

  var INK = { light: [0.12, 0.11, 0.09], dark: [0.96, 0.94, 0.91] };
  var COLOUR = {
    light: {"8": [0.776, 0.157, 0.157], "7": [0.114, 0.306, 0.847], "17": [0.082, 0.502, 0.239], "35": [0.541, 0.294, 0.059], "16": [0.541, 0.427, 0.0], "9": [0.055, 0.455, 0.565], "15": [0.706, 0.325, 0.035], "53": [0.494, 0.133, 0.808]},
    dark: {"8": [1.0, 0.541, 0.502], "7": [0.541, 0.706, 1.0], "17": [0.29, 0.871, 0.502], "35": [0.878, 0.627, 0.376], "16": [0.902, 0.831, 0.353], "9": [0.369, 0.878, 0.878], "15": [1.0, 0.663, 0.302], "53": [0.78, 0.573, 0.918]}
  };
  function dark() { return !!window.__rdDark; }
  function palette(colourful) {
    var ink = dark() ? INK.dark : INK.light, p = { '-1': ink, '1': ink, '6': ink };
    if (colourful) { var c = dark() ? COLOUR.dark : COLOUR.light; for (var k in c) p[k] = c[k]; }
    else { [7, 8, 9, 15, 16, 17, 35, 53].forEach(function (z) { p[String(z)] = ink; }); }
    return p;
  }
  var parts = [], BIN = null, RD = null, failure = '';
  window.rdChemPush = function (b64) {
    var s = atob(b64), a = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) a[i] = s.charCodeAt(i);
    parts.push(a);
  };
  function brief(e) { return String((e && e.message) || e || 'unknown').slice(0, 100); }
  async function boot() {
    if (RD) return RD;
    if (!BIN) {
      var total = parts.reduce(function (n, p) { return n + p.length; }, 0), bin = new Uint8Array(total), at = 0;
      parts.forEach(function (p) { bin.set(p, at); at += p.length; });
      parts = [];
      BIN = bin;
    }
    if (!BIN.length) throw new Error('the engine file did not arrive');
    if (typeof initRDKitModule !== 'function') throw new Error('the engine script did not load');
    RD = await initRDKitModule({
      instantiateWasm: function (imports, done) {
        WebAssembly.instantiate(BIN, imports).then(function (r) { done(r.instance, r.module); }, function (e) { failure = 'wasm: ' + brief(e); });
        return {};
      }
    });
    return RD;
  }

  var FONT = "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif";
  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  // Tight bounds of everything RDKit drew. Atom labels are outlines, so their points count too.
  function bounds(svg) {
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, re = / d='([^']*)'/g, m;
    while ((m = re.exec(svg))) {
      var n = m[1].replace(/[A-Za-z]/g, ' ').trim().split(/[\s,]+/).map(Number);
      for (var i = 0; i + 1 < n.length; i += 2) {
        if (!isFinite(n[i]) || !isFinite(n[i + 1])) continue;
        if (n[i] < x0) x0 = n[i]; if (n[i] > x1) x1 = n[i];
        if (n[i + 1] < y0) y0 = n[i + 1]; if (n[i + 1] > y1) y1 = n[i + 1];
      }
    }
    return x1 < x0 ? null : { x0: x0, y0: y0, x1: x1, y1: y1 };
  }

  // One molecule at a fixed bond length, cropped to its drawing, so every piece of a scheme has the same scale.
  function piece(rd, src, name, hydrogens, bond) {
    var mol = null;
    try { mol = rd.get_mol(src); } catch (e) { mol = null; }
    if (!mol || !mol.is_valid()) { if (mol) mol.delete(); return null; }
    var out = null;
    try {
      var st = STYLES[name] || STYLES.skeletal;
      var showH = hydrogens === 'explicit' ? true : hydrogens === 'implicit' ? false : !!st.h;
      if (showH) { var withH = mol.add_hs(); var m2 = rd.get_mol(withH); mol.delete(); mol = m2; }
      mol.set_new_coords();
      var o = Object.assign({ width: 1400, height: 1050, clearBackground: false, fixedBondLength: bond, padding: 0.05, atomColourPalette: palette(st.c !== false) }, st.o || {});
      var svg = mol.get_svg_with_highlights(JSON.stringify(o));
      var b = bounds(svg);
      if (b) {
        var pad = 5, body = svg.split('<!-- END OF HEADER -->')[1] || '';
        body = body.replace(/<\/svg>\s*$/, '').replace(/#000000/gi, 'currentColor');
        out = { w: b.x1 - b.x0 + 2 * pad, h: b.y1 - b.y0 + 2 * pad, vb: [b.x0 - pad, b.y0 - pad, b.x1 - b.x0 + 2 * pad, b.y1 - b.y0 + 2 * pad], body: body };
      }
    } catch (e) { out = null; }
    mol.delete();
    return out;
  }
  function place(p, x, y) {
    return "<svg x='" + x.toFixed(1) + "' y='" + y.toFixed(1) + "' width='" + p.w.toFixed(1) + "' height='" + p.h.toFixed(1) + "' viewBox='" + p.vb.map(function (v) { return v.toFixed(1); }).join(' ') + "'>" + p.body + '</svg>';
  }
  function pretty(t) { return String(t).replace(/\bhv\b/g, 'h\u03bd').replace(/\bDelta\b/g, '\u0394').replace(/\bdeg\b/g, '\u00b0'); }
  // Label text: digits after a letter or bracket become subscripts (H2SO4); +, - and a count before them become a charge (H+, Fe3+, SO4 2-).
  function label(text, cx, y, fs) {
    var t = pretty(text), parts = '', i = 0;
    function sup(txt) { return "<tspan font-size='" + (fs * 0.7).toFixed(1) + "' dy='" + (-fs * 0.4).toFixed(1) + "'>" + esc(txt) + "</tspan><tspan dy='" + (fs * 0.4).toFixed(1) + "'>\u200b</tspan>"; }
    function sb(txt) { return "<tspan font-size='" + (fs * 0.7).toFixed(1) + "' dy='" + (fs * 0.25).toFixed(1) + "'>" + esc(txt) + "</tspan><tspan dy='" + (-fs * 0.25).toFixed(1) + "'>\u200b</tspan>"; }
    while (i < t.length) {
      var rest = t.slice(i), m;
      if ((m = /^\^\{?([0-9]*[+\-\u2212]|[+\-\u2212][0-9]*)\}?/.exec(rest)) || (i > 0 && /[A-Za-z)\]0-9]/.test(t[i - 1]) && (m = /^([0-9]*[+\-\u2212])(?![A-Za-z0-9])/.exec(rest)))) {
        parts += sup(m[1].replace('-', '\u2212')); i += m[0].length; continue;
      }
      if (/\d/.test(t[i]) && i > 0 && /[A-Za-z)\]]/.test(t[i - 1])) {
        var j = i; while (j < t.length && /\d/.test(t[j])) j++;
        if (j < t.length && /[+\-\u2212]/.test(t[j]) && !/[A-Za-z0-9]/.test(t[j + 1] || '')) { parts += sup(t.slice(i, j + 1).replace('-', '\u2212')); i = j + 1; continue; }
        parts += sb(t.slice(i, j)); i = j; continue;
      }
      parts += esc(t[i]); i++;
    }
    return "<text x='" + cx.toFixed(1) + "' y='" + y.toFixed(1) + "' font-family=\"" + FONT + "\" font-size='" + fs + "' fill='currentColor' text-anchor='middle'>" + parts + '</text>';
  }
  function textWidth(t, fs) { return String(pretty(t)).replace(/[\^{}]/g, '').length * fs * 0.52; }
  function side(str) {
    return str.split('.').map(function (s) { return s.trim(); }).filter(Boolean).map(function (s) {
      var m = /^(\d+)(?=[A-Za-z\[])(.*)$/.exec(s);
      return m ? { coef: m[1], smi: m[2] } : { coef: '', smi: s };
    });
  }

  // reactants>agents>products, a label for the arrow ("above | below"), the style and the arrow shape. Returns { w, h, svg } or null.
  function reaction(rd, spec, text, name, hydrogens, arrow) {
    var seg = String(spec).split('>');
    if (seg.length !== 3 || !seg[0].trim() || !seg[2].trim()) return null;
    var BOND = 26, LS = 14;
    var left = side(seg[0]), agents = side(seg[1]), right = side(seg[2]);
    function build(list, bond) {
      var out = [];
      for (var i = 0; i < list.length; i++) {
        var p = piece(rd, list[i].smi, name, hydrogens, bond);
        if (!p) return null;
        out.push({ coef: list[i].coef, p: p });
      }
      return out;
    }
    var L = build(left, BOND), R = build(right, BOND), A = agents.length ? build(agents, 14) : [];
    if (!L || !R || !A) return null;
    var up = '', down = '';
    if (text) { var bar = String(text).split('|'); up = bar[0].trim(); down = (bar[1] || '').trim(); }
    var maxHalf = 20;
    L.concat(R).forEach(function (m) { maxHalf = Math.max(maxHalf, m.p.h / 2); });
    var agentH = 0, agentW = 0;
    A.forEach(function (a) { agentH = Math.max(agentH, a.p.h); agentW += a.p.w + 8; });
    var upH = (agentH ? agentH + 6 : 0) + (up ? LS + 6 : 0), downH = down ? LS + 8 : 0;
    var arrowLen = Math.max(78, Math.max(textWidth(up, LS), textWidth(down, LS), agentW) + 24);
    var half = maxHalf + 4;
    var cy = Math.max(half, upH + 10), bottom = Math.max(half, downH + 10);
    var H = cy + bottom, x = 8, bits = '';
    function row(list) {
      list.forEach(function (m, i) {
        if (i > 0) { bits += "<text x='" + (x + 11).toFixed(1) + "' y='" + (cy + 7).toFixed(1) + "' font-family=\"" + FONT + "\" font-size='22' fill='currentColor' text-anchor='middle'>+</text>"; x += 22; }
        if (m.coef) { bits += "<text x='" + (x + 6).toFixed(1) + "' y='" + (cy + 7).toFixed(1) + "' font-family=\"" + FONT + "\" font-size='20' fill='currentColor' text-anchor='middle'>" + esc(m.coef) + '</text>'; x += 20; }
        bits += place(m.p, x, cy - m.p.h / 2); x += m.p.w;
      });
    }
    row(L);
    x += 14;
    var ax0 = x, ax1 = x + arrowLen, mid = (ax0 + ax1) / 2;
    if (arrow === 'reversible') {
      var up1 = cy - 4.5, dn1 = cy + 4.5;
      bits += "<path d='M " + ax0 + ' ' + up1 + ' L ' + ax1 + ' ' + up1 + ' L ' + (ax1 - 9) + ' ' + (up1 - 6) + ' M ' + ax1 + ' ' + dn1 + ' L ' + ax0 + ' ' + dn1 + ' L ' + (ax0 + 9) + ' ' + (dn1 + 6) + "' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/>";
    } else if (arrow === 'back') {
      bits += "<path d='M " + (ax0 + 8) + ' ' + cy + ' L ' + ax1 + ' ' + cy + "' stroke='currentColor' stroke-width='2' stroke-linecap='round'/><polygon points='" + ax0 + ',' + cy + ' ' + (ax0 + 10) + ',' + (cy - 5.5) + ' ' + (ax0 + 10) + ',' + (cy + 5.5) + "' fill='currentColor'/>";
    } else {
      bits += "<path d='M " + ax0 + ' ' + cy + ' L ' + (ax1 - 8) + ' ' + cy + "' stroke='currentColor' stroke-width='2' stroke-linecap='round'/><polygon points='" + ax1 + ',' + cy + ' ' + (ax1 - 10) + ',' + (cy - 5.5) + ' ' + (ax1 - 10) + ',' + (cy + 5.5) + "' fill='currentColor'/>";
    }
    var top = cy - 8;
    if (up) { bits += label(up, mid, top, LS); top -= LS + 4; }
    if (A.length) { var ax = mid - (agentW - 8) / 2; A.forEach(function (a) { bits += place(a.p, ax, top - a.p.h); ax += a.p.w + 8; }); }
    if (down) bits += label(down, mid, cy + 8 + LS, LS);
    x = ax1 + 14;
    row(R);
    var W = Math.ceil(x + 8);
    return { w: W, h: Math.ceil(H), svg: "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 " + W + ' ' + Math.ceil(H) + "' width='" + W + "' height='" + Math.ceil(H) + "' style='max-width:100%;height:auto'>" + bits + '</svg>' };
  }

  // A structure or reaction inside a table cell.
  function drawCell(el, rd) {
    var src = el.dataset.src || '', kind = el.dataset.kind, name = el.dataset.style || 'skeletal';
    var st = STYLES[name] || STYLES.skeletal;
    try {
      if (kind === 'rxn') {
        var r = reaction(rd, src, '', name, '', 'forward');
        if (!r) return false;
        el.innerHTML = r.svg;
        var s = el.querySelector('svg'); s.style.width = Math.min(r.w, 340) + 'px';
      } else {
        var mol = rd.get_mol(src);
        if (!mol || !mol.is_valid()) { if (mol) mol.delete(); return false; }
        var showH = !!st.h;
        if (showH) { var withH = mol.add_hs(); var m2 = rd.get_mol(withH); mol.delete(); mol = m2; }
        mol.set_new_coords();
        var o = Object.assign({ width: 140, height: 105, clearBackground: false, atomColourPalette: palette(st.c !== false) }, st.o || {});
        var svg = mol.get_svg_with_highlights(JSON.stringify(o)).replace(/<\?xml[^>]*\?>\s*/, '').replace(/#000000/gi, 'currentColor');
        mol.delete();
        el.innerHTML = svg;
      }
      el.dataset.drawn = '1';
      return true;
    } catch (e) { return false; }
  }
  function draw(fig, rd) {
    var lang = fig.dataset.lang || 'smiles', name = fig.dataset.style || 'skeletal';
    var st = STYLES[name] || STYLES.skeletal;
    var src = fig.querySelector('.chem-src'); if (!src) return 0;
    var lines = lang === 'mol' ? [src.textContent] : src.textContent.split('\n').map(function (s) { return s.trim(); }).filter(Boolean);
    var row = document.createElement('div'); row.className = 'chem-row';
    var bad = [], made = 0;
    lines.forEach(function (line) {
      var smi = line, cap = '';
      if (lang !== 'mol') { var sp = line.search(/\s/); if (sp > 0) { smi = line.slice(0, sp); cap = line.slice(sp).trim(); } }
      if (fig.dataset.reaction === '1' && lang !== 'mol') {
        var rx = null;
        try { rx = reaction(rd, smi, fig.dataset.conditions || '', name, fig.dataset.hydrogens || '', fig.dataset.arrow || 'forward'); } catch (e) { rx = null; }
        if (!rx) { bad.push(smi); return; }
        var ritem = document.createElement('div'); ritem.className = 'chem-item chem-rxn'; ritem.innerHTML = rx.svg; ritem.dataset.smi = smi;
        var rs = ritem.querySelector('svg'); rs.style.width = Math.min(rx.w, Math.max(parseInt(fig.dataset.width, 10) || 300, 560)) + 'px';
        if (cap) { var rc = document.createElement('div'); rc.className = 'chem-cap'; rc.textContent = cap; ritem.appendChild(rc); }
        row.appendChild(ritem); made++;
        return;
      }
      var mol = null;
      try { mol = rd.get_mol(smi); } catch (e) { mol = null; }
      if (!mol || !mol.is_valid()) { if (mol) mol.delete(); bad.push(lang === 'mol' ? 'the molfile' : smi); return; }
      try {
        var hyd = fig.dataset.hydrogens, showH = hyd ? hyd === 'explicit' : !!st.h;
        if (showH) { var withH = mol.add_hs(); var m2 = rd.get_mol(withH); mol.delete(); mol = m2; }
        if (lang !== 'mol' || !mol.has_coords || !mol.has_coords()) mol.set_new_coords();
        var w = parseInt(fig.dataset.width, 10) || 300, o = Object.assign({ width: w, height: Math.round(w * 0.75), clearBackground: false, atomColourPalette: palette(st.c !== false) }, st.o || {});
        if (fig.dataset.numbers === '1') o.addAtomIndices = true;
        if (fig.dataset.stereo === '1') o.addStereoAnnotation = true;
        if (fig.dataset.highlight) o.atoms = fig.dataset.highlight.split(',').map(Number);
        var svg = mol.get_svg_with_highlights(JSON.stringify(o));
        svg = svg.replace(/<\?xml[^>]*\?>\s*/, '').replace(/#000000/gi, 'currentColor');
        var item = document.createElement('div'); item.className = 'chem-item'; item.innerHTML = svg; item.dataset.smi = smi;
        if (cap) { var c = document.createElement('div'); c.className = 'chem-cap'; c.textContent = cap; item.appendChild(c); }
        row.appendChild(item); made++;
      } catch (e) { bad.push(smi); }
      mol.delete();
    });
    if (made) { src.style.display = 'none'; fig.insertBefore(row, src); }
    if (bad.length) { var er = document.createElement('div'); er.className = 'chem-error'; er.textContent = 'Could not read ' + bad.join(', ') + '. Check the notation.'; fig.appendChild(er); }
    fig.dataset.drawn = '1';
    return made;
  }
  window.rdChemTheme = function () {
    if (!RD) return;
    [].slice.call(document.querySelectorAll('.chem-block[data-drawn]')).forEach(function (f) {
      var old = f.querySelector('.chem-row'); if (old) old.remove();
      var er = f.querySelector('.chem-error'); if (er) er.remove();
      var src = f.querySelector('.chem-src'); if (src) src.style.display = '';
      draw(f, RD);
    });
    [].slice.call(document.querySelectorAll('.chem-cell[data-drawn]')).forEach(function (c) { drawCell(c, RD); });
  };
  var failedAt = 0;
  window.rdChemFailure = function () { return failure; };
  window.rdChem = async function () {
    var figs = [].slice.call(document.querySelectorAll('.chem-block:not([data-drawn])'));
    var cells = [].slice.call(document.querySelectorAll('.chem-cell:not([data-drawn])'));
    if (!figs.length && !cells.length) return 0;
    // A failed start is tried again later, so one bad moment does not turn drawing off for the page.
    if (!RD && failedAt && Date.now() - failedAt < 2000) return -1;
    var rd;
    try { rd = await boot(); failedAt = 0; failure = ''; } catch (e) {
      failedAt = Date.now(); failure = failure || brief(e);
      figs.forEach(function (f) {
        var er = f.querySelector('.chem-error'); if (er) er.remove();
        er = document.createElement('div'); er.className = 'chem-error';
        er.textContent = 'The molecule drawing engine could not start: ' + failure + '.'; f.appendChild(er);
      });
      return -1;
    }
    figs.forEach(function (f) { var er = f.querySelector('.chem-error'); if (er) er.remove(); });
    var n = 0;
    figs.forEach(function (f) { n += draw(f, rd); });
    cells.forEach(function (c) { if (drawCell(c, rd)) n++; else { c.dataset.drawn = '1'; c.classList.add('chem-cell-bad'); } });
    return n;
  };
})();
