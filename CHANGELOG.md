## Unreleased

- Outline `/Count` sign now sets bookmark open state, fixture-driven integration test ensures actions import correctly.
- Added `PDAnnotation`/`PDAnnotationLink` wrappers and page integration so `/Annots` resolve destinations/actions alongside outlines.
- Extended annotation support with color, appearance and border helpers (`PDAppearanceDictionary`, `PDBorderStyleDictionary`) plus specialized `Text`/`Widget` wrappers leveraging `PDAppearanceCharacteristicsDictionary`; updated unit tests cover the new accessors.
- `COSParser` gains lenient recovery via `BruteForceParser` when `startxref` is corrupt and surfaces logging for skipped objects, while `PDDocument` exposes the `/Encrypt` dictionary through a new `PDEncryption` wrapper with dedicated tests.
- Introduced generated outline fixtures (`outline_actions.pdf`, `outline_actions_remote.pdf`) covering named, remote and URI actions with corresponding integration tests.

## 1.0.0

- Initial version.
