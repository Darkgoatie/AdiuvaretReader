import Foundation

public enum EpubCSS {
    /// Style sheet injected into every chapter. Colours are `#RRGGBB`.
    public static func make(text: String, ground: String, link: String, fontStack: String, fontSize: Double,
                            lineHeight: Double, sidePadding: Double, fontFileURL: String?) -> String {
        var css = ""
        if let u = fontFileURL {
            css += "@font-face{font-family:'Google Sans';src:url('\(u)');font-weight:100 900;}\n"
        }
        css += """
        html{background:\(ground)!important;-webkit-text-size-adjust:none;}
        body{background:\(ground)!important;color:\(text)!important;font-family:\(fontStack)!important;font-size:\(Int(fontSize))px!important;line-height:\(lineHeight)!important;padding:24px \(Int(sidePadding))px 120px!important;margin:0 auto!important;max-width:44em;overflow-wrap:break-word;}
        body *{color:inherit!important;background-color:transparent!important;}
        body *:not(pre):not(code):not(kbd):not(samp):not(.katex):not(.katex *){font-family:inherit!important;}
        .math-block{overflow-x:auto;overflow-y:hidden;padding:4px 0;}
        .katex{font-size:1.08em;}
        a,a *{color:\(link)!important;}
        img,svg,video{max-width:100%!important;height:auto!important;}
        h1,h2,h3,h4{line-height:1.25!important;}
        body mark.rd-hl{background-color:rgba(42,185,133,0.35)!important;color:inherit!important;border-radius:3px;}
        body mark.rd-hl-yellow{background-color:rgba(240,200,60,0.45)!important;}
        body mark.rd-hl-blue{background-color:rgba(70,140,230,0.38)!important;}
        body mark.rd-hl-pink{background-color:rgba(230,100,150,0.38)!important;}
        body mark.rd-find{background-color:rgba(240,177,74,0.55)!important;color:inherit!important;border-radius:3px;}
        a.internal-link{text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:2px;}
        a.internal-link.is-unresolved{opacity:.65;text-decoration-style:dotted;}
        a.ob-tag{background-color:rgba(42,185,133,0.16)!important;border-radius:999px;padding:0 .55em;text-decoration:none;font-size:.92em;white-space:nowrap;}
        mark.ob-hl{background-color:rgba(240,177,74,0.45)!important;color:inherit!important;border-radius:3px;padding:0 2px;}
        .ob-properties{border:1px solid rgba(128,128,128,.35);border-radius:12px;padding:8px 14px;margin:0 0 1.2em;font-size:.88em;}
        .ob-prop{display:flex;gap:12px;padding:4px 0;align-items:baseline;}
        .ob-prop-key{min-width:6.5em;opacity:.7;}
        .ob-prop-val{flex:1;}
        .ob-chip{border:1px solid rgba(128,128,128,.45);border-radius:8px;padding:0 .5em;margin-right:4px;white-space:nowrap;}
        .callout{border-left:4px solid #3B82F6;background-color:rgba(59,130,246,.10)!important;border-radius:10px;margin:1em 0;padding:0;overflow:hidden;}
        .co-head{display:flex;gap:8px;align-items:center;padding:10px 14px;font-weight:600;cursor:default;list-style:none;}
        summary.co-head{cursor:pointer;}
        summary.co-head::-webkit-details-marker{display:none;}
        .co-body{padding:0 14px 6px;}
        .co-body>*:first-child{margin-top:0;}
        .co-icon{width:1.2em;text-align:center;}
        .co-tip,.co-success{border-left-color:#2AB985;background-color:rgba(42,185,133,.12)!important;}
        .co-warning,.co-example{border-left-color:#E0A030;background-color:rgba(224,160,48,.14)!important;}
        .co-danger,.co-failure,.co-bug{border-left-color:#E5484D;background-color:rgba(229,72,77,.12)!important;}
        .co-question{border-left-color:#E0A030;background-color:rgba(224,160,48,.12)!important;}
        .co-quote{border-left-color:#888;background-color:rgba(128,128,128,.12)!important;}
        .co-abstract,.co-todo{border-left-color:#22A6B3;background-color:rgba(34,166,179,.12)!important;}
        blockquote{border-left:3px solid rgba(42,185,133,.7);margin:1em 0;padding:0 14px;opacity:.95;}
        .ob-table{overflow-x:auto;margin:1em 0;}
        table{border-collapse:collapse;}
        th,td{border:1px solid rgba(128,128,128,.4);padding:6px 10px;}
        th{background-color:rgba(128,128,128,.12)!important;}
        .ob-embed{border-left:3px solid rgba(128,128,128,.5);padding:2px 14px;margin:1em 0;background-color:rgba(128,128,128,.07)!important;border-radius:6px;}
        .ob-embed-title{font-size:.8em;opacity:.65;margin-bottom:4px;}
        .ob-missing{opacity:.7;font-style:italic;}
        .ob-note{opacity:.6;font-size:.8em;}
        .ob-pdf{border:1px solid rgba(128,128,128,.45);border-radius:8px;padding:2px 10px;text-decoration:none;}
        ul.contains-task-list{list-style:none;padding-left:.4em;}
        li.task-list-item{display:flex;gap:.6em;align-items:baseline;}
        li.task-list-item>*:not(.task-box){flex:1;}
        .task-box{display:inline-block;width:1.05em;height:1.05em;border:1.5px solid currentColor;border-radius:4px;text-align:center;line-height:1em;font-size:.8em;flex:none;transform:translateY(.1em);}
        li.is-checked .task-box{background-color:#2AB985!important;border-color:#2AB985;color:#10201A!important;}
        li.is-checked{opacity:.75;}
        .footnotes{font-size:.88em;opacity:.9;}
        sup.fn-ref a,a.fn-back{text-decoration:none;}
        audio,video{max-width:100%;}
        img.ob-img{border-radius:6px;}
        ::selection{background:rgba(42,185,133,0.4);}
        """
        return css
    }
}
