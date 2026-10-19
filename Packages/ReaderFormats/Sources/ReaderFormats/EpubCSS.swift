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
        body *:not(pre):not(code):not(kbd):not(samp){font-family:inherit!important;}
        a,a *{color:\(link)!important;}
        img,svg,video{max-width:100%!important;height:auto!important;}
        h1,h2,h3,h4{line-height:1.25!important;}
        body mark.rd-hl{background-color:rgba(42,185,133,0.35)!important;color:inherit!important;border-radius:3px;}
        body mark.rd-find{background-color:rgba(240,177,74,0.55)!important;color:inherit!important;border-radius:3px;}
        ::selection{background:rgba(42,185,133,0.4);}
        """
        return css
    }
}
