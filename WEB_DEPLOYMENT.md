# Field Measure Pro — Flutter Web

## Local test

```powershell
flutter pub get
flutter run -d chrome
```

## Production build for GitHub Pages

If the repository is named `field-measure-pro`:

```powershell
flutter build web --release --base-href "/field-measure-pro/"
```

The production files are generated in `build/web`.

## Notes

- Browser GPS requires a secure context (HTTPS), which GitHub Pages provides.
- Field records and settings use `shared_preferences`, which maps to browser local storage on Web.
- Imports read selected files as bytes, avoiding `dart:io` in the browser.
- Exports are generated as in-memory `XFile` objects so PDF/GeoJSON/KML/CSV sharing does not require a native filesystem path.
- Map tiles are loaded from the configured public tile providers; review their usage/attribution terms before production-scale use.
