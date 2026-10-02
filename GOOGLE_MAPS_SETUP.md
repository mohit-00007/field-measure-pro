# Google Maps browser setup

This project is configured for Google Maps **in the browser only**.

## Google Cloud

1. Create/select a Google Cloud project.
2. Enable **Maps JavaScript API**.
3. Create an API key.
4. Add an HTTP referrer restriction for:
   `https://mohit-00007.github.io/*`
5. Restrict the key to **Maps JavaScript API**.

Google Maps Platform generally requires billing to be enabled. Keep the key restricted.

## Local build

Edit `web/index.html` and replace:

`YOUR_GOOGLE_MAPS_API_KEY`

with your restricted browser key, then run:

```powershell
flutter clean
flutter pub get
flutter build web --release --base-href "/field-measure-pro/"
```

## GitHub Pages

Do not commit a real unrestricted key. Add a repository secret:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Name:

`GOOGLE_MAPS_API_KEY`

The GitHub Actions workflow replaces the placeholder at build time.


## Place Search

Enable **Places API (New)** for the browser place-search/autocomplete box. The app uses Google's current Place Autocomplete widget and only requests display name, formatted address, location, and viewport.
