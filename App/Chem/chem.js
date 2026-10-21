(function () {
  if (window.rdChem) return;
  var STYLES = {
    skeletal: {},
    explicit: { h: true, o: { explicitMethyl: true } },
    color: { o: { useCDKAtomPalette: true } },
    bw: { o: { useBWAtomPalette: true } },
    comic: { o: { comicMode: true } },
    compact: { o: { bondLineWidth: 1, baseFontSize: 0.45, padding: 0.04 } },
    bold: { o: { bondLineWidth: 3, useBWAtomPalette: true } }
  };
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
        var w = parseInt(fig.dataset.width, 10) || 300, o = Object.assign({ width: w, height: Math.round(w * 0.75), clearBackground: false }, st.o || {});
        if (fig.dataset.numbers === '1') o.addAtomIndices = true;
        if (fig.dataset.stereo === '1') o.addStereoAnnotation = true;
        if (fig.dataset.highlight) o.atoms = fig.dataset.highlight.split(',').map(Number);
        var svg = mol.get_svg_with_highlights(JSON.stringify(o));
        svg = svg.replace(/<\?xml[^>]*\?>\s*/, '').replace(/#000000/gi, 'currentColor');
        var item = document.createElement('div'); item.className = 'chem-item'; item.innerHTML = svg;
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
