# Field Measure Pro (FMP)

> **"Measure. Adjust. Know."**  
> High-precision land and field boundary measurement application for **Android** and **Windows**, powered by Flutter.

---

## 1. Product Overview

Field Measure Pro is a professional field-measurement application designed for farmers, agronomists, land appraisers, property managers, and field workers. It combines **real-time outdoor GPS perimeter tracking** with **intuitive touch/mouse boundary drawing** and an authoritative **Polygon Editor** for interactive boundary fine-tuning.

---

## 2. Geometry & Geodesic Accuracy Documentation (Section 19)

Field Measure Pro calculates geodesic surface areas and perimeters using spherical excess integration on the **WGS84 authalic sphere** (authalic radius $R_a = 6,371,007.2\text{ m}$, semi-major axis $a = 6,378,137.0\text{ m}$, flattening $f = 1/298.257223563$).
- **Consumer Hardware**: GPS accuracy is tracked and displayed exactly as reported by the device hardware (`±X.X m`). Accuracies are never fabricated.
- **Interactive Boundary Editing**: Vertices can be adjusted visually against high-resolution satellite imagery to fine-tune GPS walking baselines.
- **Survey Disclaimer**: Measurements are estimates for agricultural and planning purposes and are not legally certified cadastral surveys.

---

## 2. Key Features

- **GPS Walk**: Live perimeter tracking using real device GPS. Collects raw latitude, longitude, altitude, speed, heading, and reported GPS accuracy. Gated to consumer GPS without fabricated accuracies.
- **Draw on Map**:
  - *Freehand Draw*: Single-stroke boundary drawing with RDP (Ramer-Douglas-Peucker) simplification.
  - *Point-by-Point*: Tap-to-place individual boundary corners with undo and auto-close.
  - *Draw / Pan Toggle*: Seamlessly pan and zoom satellite maps before drawing.
- **Boundary Editor (Authoritative Controller)**:
  - Single authoritative polygon source of truth (`PolygonEditorController.points`).
  - Smooth vertex dragging with camera-derived coordinate transformations.
  - **Drag Cancellation**: Canceling gesture restores exact original coordinates without polluting undo history.
  - **1 Drag = 1 Undo Entry**: 100 pointer move events create exactly one history state.
  - **Live Geodesic Area & Perimeter**: Updates continuously while dragging.
  - **Midpoint Insertion (+)**: Generates draggable vertices along any edge.
  - **Vertex Deletion Safety Guard**: Prevents reduction below 3 points (`"At least 3 boundary points are required."`).
  - **Self-Intersection Validation**: Prevents invalid self-crossing boundaries (`"Boundary crosses itself."`).
- **GPS + Adjust Workflow**: Walk with GPS, generate baseline perimeter, adjust vertices manually, and preserve both original GPS area and final adjusted area.
- **Land Revenue Units & Custom Land Unit Editor**:
  - Standard metric and imperial: Acres, Hectares, Square Meters, Square Feet, Square Yards.
  - Pre-configured regional revenue presets: Uttarakhand, Uttar Pradesh (Pucca & Kaccha), Bihar, Punjab & Haryana, Rajasthan, Madhya Pradesh.
  - **Custom Land Unit Editor**: Define custom localized units (e.g. *Local Bigha = 2,500 m²*) and save conversion values directly with each measurement.
- **Crash & Session Recovery**: Automatically drafts active sessions with state tracking (`TRACKING`, `PAUSED`, `DRAWING`, `EDITING`, `READY_TO_SAVE`) and prompts to resume on restart.
- **My Fields Repository**: Search fields by name, sort by Newest/Oldest/Largest/Smallest, view lightweight boundary preview thumbnails, duplicate, edit, rename, and export.
- **Import & Export Engine**:
  - *Import*: File picker supporting KML, GeoJSON, CSV, and JSON with coordinate validation.
  - *Export*: GeoJSON, KML, CSV, JSON, and professional PDF reports with boundary visualization diagrams and coordinate tables.
- **Windows Desktop Features**: Native mouse editing, keyboard shortcuts (`Ctrl+Z`, `Ctrl+Y`, `Delete`, `Escape`, `Enter`), and SQLite FFI runtime support.

---

## 3. Architecture

```
User Input (Touch / Mouse / GPS)
              ↓
        FieldMapView
 (48×48px outdoor touch targets,
  camera.screenPointToLatLng)
              ↓
  Explicit Interaction Callbacks
(onVertexDragStart, onVertexDrag,
 onVertexDragEnd, onVertexDragCancel,
 onMidpointInsert, onVertexSelected)
              ↓
    PolygonEditorController
(Sole Source of Truth, Drag Lifecycle,
 Single-Step Undo Stack, Validation)
              ↓
       Geometry Engine
(WGS84 Authalic-Sphere Calculator & Validator)
              ↓
   Live Metrics & Storage
(UnitSettings, SQLite Persistence,
 Session Recovery, PDF Generator)
```

---

## 4. Building & Running

### Prerequisites
- Flutter SDK `>=3.10.0`
- Android SDK (for Android build)
- Visual Studio with C++ desktop workload (for Windows build)

### Run Locally
```bash
# Get dependencies
flutter pub get

# Run on connected Android device
flutter run -d android

# Run on Windows Desktop
flutter run -d windows
```

### Build Release Artifacts
```bash
# Android APK
flutter build apk --release

# Windows Executable
flutter build windows --release
```

---

## 5. Testing Suite

The project includes unit, geometry, and widget tests:
- `test/polygon_editor_test.dart`: Tests 1–8 (Move vertex, Live area, Drag finish & undo, Redo, Midpoint insertion, Deletion guard, Self-intersection validation, Multiple drags, GPS + Adjust separation).
- `test/boundary_editor_widget_test.dart`: End-to-end pointer drag, live HUD area update, and undo widget verification.
- `test/touch_and_editor_test.dart`: Closed-loop finger path (P1–P4–P1), RDP simplification, and boundary handover.
- `test/geometry_test.dart`: Deterministic 100m × 50m calibration polygon ($\approx 5,000\text{ m}^2$).
- `test/unit_conversion_test.dart`: Regional unit conversion calculations.

Run tests:
```bash
flutter test
```

---

## 6. Disclaimers & Legal Notice

GPS/map-based measurements provided by consumer hardware are estimates subject to atmospheric conditions, satellite geometry, and multipath interference. Calculations use a spherical excess approximation on the WGS84 authalic sphere. Field Measure Pro is designed for agricultural planning, field boundary estimation, and property management. It is **not** a replacement for a legally certified cadastral survey conducted by a licensed surveyor.


## Browser Google Maps setup

This Web build uses `google_maps_flutter` and the Google Maps JavaScript API. The map is browser-only; no Android Google Maps configuration is required for the GitHub Pages site.

1. In Google Cloud, enable **Maps JavaScript API** and create a browser-restricted API key.
2. Restrict the key to `https://mohit-00007.github.io/*` (or your final GitHub Pages origin).
3. Open `web/index.html` and replace `YOUR_GOOGLE_MAPS_API_KEY` with that key for a local build.
4. For GitHub Actions, add a repository secret named `GOOGLE_MAPS_API_KEY`; the included workflow injects it at build time.

Google Maps requires a valid API key and an eligible Google Cloud billing setup. See the official setup documentation: https://developers.google.com/maps/flutter-package/config

## Payments / Premium

The web build now includes a subscription gate after the first free measurement. Premium pricing is ₹99/month or ₹990/year. See `PAYMENTS_SETUP.md` and `backend/README.md` for the Razorpay + UPI AutoPay backend setup. Payment secrets must remain server-side.
