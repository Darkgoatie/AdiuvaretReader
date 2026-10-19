# Module: ReaderFormats

## Responsibility
EPUB, PDF and text parsing and rendering; Locator; selection events.

Does NOT: use another module's internals, log book content, use the network.

## Public interface
| Name | Signature | Errors |
|---|---|---|
| tbd | defined by the task that builds it | |

## Invariants
- No book content in logs.

## Depends on
- tbd

## Owned files
- Packages/ReaderFormats/

## Testing in isolation
swift test --package-path Packages/ReaderFormats (GitHub runner)

## Deviations
