# Module: ReaderFiles

## Responsibility
The library folder tree on disk: list, create folder, rename, move, copy, delete to Recently Deleted, restore, search by name, sizes, rescan, security-scoped bookmarks for user-granted external folders.

Does NOT: parse book formats, hold annotations (ReaderStore), render UI, use the network, or touch paths outside the library root or a granted bookmark.

## Public interface
| Name | Signature | Errors |
|---|---|---|
| tbd | defined by task 15 | nameCollision, outsideRoot, moveIntoSelf, notFound |

## Invariants
- Every path is resolved and checked to stay inside the library root or a granted folder.
- Delete is a move into Recently Deleted; permanent removal only after 30 days or on explicit empty.
- Names never silently overwrite; collisions get a numeric suffix or an error.
- No file names or contents in logs.

## Depends on
- ReaderStore: Book records updated when a file moves or is deleted.

## Owned files
- Packages/ReaderFiles/

## Testing in isolation
swift test --package-path Packages/ReaderFiles (GitHub runner)

## Deviations
