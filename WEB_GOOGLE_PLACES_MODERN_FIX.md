# Google Places Search Fix

This version uses the current Google Maps JavaScript API PlaceAutocompleteElement with the `gmp-select` event and `Place.fetchFields()`. It replaces the legacy `google.maps.places.Autocomplete` integration.

Required Google Cloud APIs: Maps JavaScript API and Places API (New). The GitHub Actions workflow injects `GOOGLE_MAPS_API_KEY` into web/index.html during deployment.
