# Google Places Search

The Web app now includes the Google Maps JavaScript API Place Autocomplete widget.

Enable **Places API (New)** in the same Google Cloud project used for Maps JavaScript API. The browser key should be restricted to:

`https://mohit-00007.github.io/*`

The GitHub Actions workflow injects `GOOGLE_MAPS_API_KEY` into `web/index.html` during deployment.

The search box supports place names, addresses, villages, cities, landmarks, and other Google place predictions. Selecting a result centers the map and adds a red marker.
