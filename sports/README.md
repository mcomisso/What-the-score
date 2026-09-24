# Sport catalog

`catalog-v1.json` is the bundled fallback and the file served from the repository's `main` branch. The iOS app fetches the raw file at `https://raw.githubusercontent.com/mcomisso/What-the-score/main/sports/catalog-v1.json`, caches the last valid response, and uses the bundled file when offline or when the remote data fails validation.

To change the catalog, edit `catalog-v1.json` in a pull request. Keep `schemaVersion` at `1`, give every sport a stable unique `id`, and provide its display name, singular and plural interval terms, and positive scoring values. You can also provide `symbolName`, the name of an SF Symbol available on iOS 17 or later, for the sport picker. For example, `"symbolName": "tennisball.fill"`. This field is optional so older catalogs still load: bundled sports use their built-in icons, and other sports use `sportscourt.fill`. Symbol names may contain lowercase letters, digits, and periods, up to 80 characters. Run the catalog validation tests, review the wording, scoring values, and symbols, then merge to `main`. Existing app installs will pick up the published JSON on their next refresh. A new app build is needed to update the bundled offline fallback.

This file contains display data only. It cannot change app code or executable behavior.
