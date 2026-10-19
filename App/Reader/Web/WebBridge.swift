import Foundation

enum WebBridge {
    /// Runs in its own content world, so scripts inside a book cannot see or call it.
    static let script = #"""
    (function () {
      if (window.rd) return;
      var post = function (o) { window.webkit.messageHandlers.rd.postMessage(o); };
      function textNodes() {
        var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
          acceptNode: function (n) {
            var p = n.parentNode ? n.parentNode.nodeName : '';
            return (p === 'SCRIPT' || p === 'STYLE') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
          }
        });
        var a = [];
        while (w.nextNode()) a.push(w.currentNode);
        return a;
      }
      function norm(s) { return s.replace(/\s+/g, ' ').trim().toLowerCase(); }
      function mark(q, cls, all) {
        q = norm(q || '');
        if (!q || !document.body) return [];
        var nodes = textNodes(), flat = '', nodeIdx = [], off = [], lastSpace = true;
        nodes.forEach(function (n, ni) {
          var v = n.nodeValue;
          for (var i = 0; i < v.length; i++) {
            var c = v.charAt(i);
            if (/\s/.test(c)) {
              if (lastSpace) continue;
              flat += ' '; lastSpace = true;
            } else {
              flat += c.toLowerCase(); lastSpace = false;
            }
            nodeIdx.push(ni); off.push(i);
          }
        });
        var starts = [], from = 0, at;
        while ((at = flat.indexOf(q, from)) >= 0) {
          starts.push(at);
          from = at + q.length;
          if (!all) break;
        }
        var made = [];
        for (var m = starts.length - 1; m >= 0; m--) {
          var s = starts[m], e = s + q.length - 1, segs = {};
          for (var k = s; k <= e; k++) {
            var ni = nodeIdx[k];
            if (!segs[ni]) segs[ni] = [off[k], off[k] + 1];
            else segs[ni][1] = off[k] + 1;
          }
          var created = [];
          Object.keys(segs).forEach(function (key) {
            var n = nodes[+key];
            if (!n.parentNode) return;
            var r = document.createRange();
            r.setStart(n, segs[key][0]);
            r.setEnd(n, Math.min(segs[key][1], n.nodeValue.length));
            var el = document.createElement('mark');
            el.className = cls;
            try { r.surroundContents(el); created.push(el); } catch (x) {}
          });
          if (created.length) made.unshift(created[0]);
        }
        return made;
      }
      function clear(cls) {
        var list = document.querySelectorAll('mark.' + cls);
        for (var i = 0; i < list.length; i++) {
          var el = list[i], p = el.parentNode;
          while (el.firstChild) p.insertBefore(el.firstChild, el);
          p.removeChild(el);
          p.normalize();
        }
      }
      window.rd = {
        setCSS: function (css) {
          var s = document.getElementById('rd-style');
          if (!s) { s = document.createElement('style'); s.id = 'rd-style'; (document.head || document.documentElement).appendChild(s); }
          s.textContent = css;
        },
        fraction: function () {
          var h = document.documentElement.scrollHeight - window.innerHeight;
          return h > 0 ? Math.min(1, Math.max(0, window.scrollY / h)) : 0;
        },
        scrollToFraction: function (f) {
          var h = document.documentElement.scrollHeight - window.innerHeight;
          window.scrollTo(0, h * f);
        },
        scrollToAnchor: function (id) {
          var el = document.getElementById(id) || document.getElementsByName(id)[0];
          if (el) el.scrollIntoView();
        },
        text: function () { return document.body ? document.body.innerText : ''; },
        setHighlights: function (list) {
          clear('rd-hl');
          for (var i = 0; i < list.length; i++) mark(list[i], 'rd-hl', false);
        },
        find: function (q) {
          clear('rd-find');
          var made = mark(q, 'rd-find', true);
          if (made.length) made[0].scrollIntoView({ block: 'center' });
          return made.length;
        },
        clearFind: function () { clear('rd-find'); },
        clearSelection: function () { window.getSelection().removeAllRanges(); },
        show: function () { document.documentElement.style.visibility = 'visible'; }
      };
      var selTimer = null;
      document.addEventListener('selectionchange', function () {
        clearTimeout(selTimer);
        selTimer = setTimeout(function () { post({ t: 'sel', v: window.getSelection().toString() }); }, 150);
      });
      var scrollTimer = null;
      window.addEventListener('scroll', function () {
        if (scrollTimer) return;
        scrollTimer = setTimeout(function () { scrollTimer = null; post({ t: 'scroll', v: window.rd.fraction() }); }, 120);
      }, { passive: true });
      document.addEventListener('click', function (e) {
        if (e.target.closest && e.target.closest('a')) return;
        if (window.getSelection().toString()) return;
        post({ t: 'tap', v: e.clientX / window.innerWidth });
      });
    })();
    """#

    static let hideUntilReady = #"""
    document.documentElement.style.visibility = 'hidden';
    setTimeout(function () { document.documentElement.style.visibility = 'visible'; }, 2000);
    """#

    static func jsString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]), let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    static func jsArray(_ items: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: items), let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}
