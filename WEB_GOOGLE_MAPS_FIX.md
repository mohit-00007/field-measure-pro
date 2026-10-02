# Google Maps Web build fix

Removed the unsupported `streetViewEnabled` argument from `GoogleMap` for the installed google_maps_flutter 2.18.2 API.

The geolocator `dart:html` messages during `flutter build web` are WebAssembly dry-run warnings; the normal dart2js build is not blocked by them.

Build:
`flutter clean`
`flutter pub get`
`flutter build web --release --base-href "/field-measure-pro/"`
