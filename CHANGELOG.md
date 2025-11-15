## Unreleased

- Outline `/Count` sign now sets bookmark open state, fixture-driven integration test ensures actions import correctly.
- Added `PDAnnotation`/`PDAnnotationLink` wrappers and page integration so `/Annots` resolve destinations/actions alongside outlines.
- Extended annotation support with color, appearance and border helpers (`PDAppearanceDictionary`, `PDBorderStyleDictionary`) plus specialized `Text`/`Widget` wrappers leveraging `PDAppearanceCharacteristicsDictionary`; updated unit tests cover the new accessors.
- `COSParser` gains lenient recovery via `BruteForceParser` when `startxref` is corrupt and surfaces logging for skipped objects, while `PDDocument` exposes the `/Encrypt` dictionary through a new `PDEncryption` wrapper with dedicated tests.
- Introduced generated outline fixtures (`outline_actions.pdf`, `outline_actions_remote.pdf`) covering named, remote and URI actions with corresponding integration tests.
- Ported the SASLprep helper used by revision 6 security handling (now backed by the `bidi` Unicode tables) and implemented the encryption dictionary writer for revision 6, wiring everything into `StandardSecurityHandler` with regression tests for dictionary creation and password fixtures.
- Hooked the encryption dictionary into both simple and full COS writers so `/Encrypt` is emitted as an indirect reference, promoting the trailer entry in `PDDocument` and adding coverage to `pd_document_test`.

## 1.0.0

- Initial version.
