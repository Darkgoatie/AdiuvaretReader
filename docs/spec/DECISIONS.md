# Decisions

| # | Decision | Reason |
|---|---|---|
| 001 | Separate repo, copied tokens | independent releases |
| 002 | Multiplatform SwiftUI target | iPhone, iPad, Mac from one code base |
| 003 | Partial file manager limited to app library and granted folders | iOS sandbox; avoids broad access and keeps privacy claim true |
| 004 | No wallpaper behind reading text | contrast and focus |
| 005 | App Group for file sharing between own apps | only supported sandbox-safe route; same team ID |
| 006 | Code viewing read-only, in-house tokenizer | keeps scope a reader; no dependency |
| 007 | App Group is group.com.halit.adiuvaret, shared by the Adiuvaret chain of apps | name belongs to the apps that use it |
