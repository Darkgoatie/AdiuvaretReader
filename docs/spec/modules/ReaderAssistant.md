# Module: ReaderAssistant

## Responsibility
Passage building, on-device model provider, quoted answers.

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
- Packages/ReaderAssistant/

## Testing in isolation
swift test --package-path Packages/ReaderAssistant (GitHub runner)

## Deviations
