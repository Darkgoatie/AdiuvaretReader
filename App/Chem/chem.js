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
  var parts = [], RD = null;
  window.rdChemPush = function (b64) {
    var s = atob(b64), a = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) a[i] = s.charCodeAt(i);
    parts.push(a);
  };
  async function boot() {
    if (RD) return RD;
    var total = parts.reduce(function (n, p) { return n + p.length; }, 0), bin = new Uint8Array(total), at = 0;
    parts.forEach(function (p) { bin.set(p, at); at += p.length; });
    parts = [];
    RD = await initRDKitModule({
      instantiateWasm: function (imports, done) {
        WebAssembly.instantiate(bin, imports).then(function (r) { done(r.instance, r.module); });
        return {};
      }
    });
    return RD;
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
  };
  window.rdChem = async function () {
    var figs = [].slice.call(document.querySelectorAll('.chem-block:not([data-drawn])'));
    if (!figs.length) return 0;
    var rd;
    try { rd = await boot(); } catch (e) {
      figs.forEach(function (f) { var er = document.createElement('div'); er.className = 'chem-error'; er.textContent = 'The molecule drawing engine could not start.'; f.appendChild(er); f.dataset.drawn = '1'; });
      return -1;
    }
    var n = 0; figs.forEach(function (f) { n += draw(f, rd); });
    return n;
  };
})();
