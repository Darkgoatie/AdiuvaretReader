# Module: ReaderStore

## Responsibility
SwiftData models Book, Progress, Highlight, Note, Bookmark; import and export.

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
- Packages/ReaderStore/

## Testing in isolation
swift test --package-path Packages/ReaderStore (GitHub runner)

## Deviations
