# Free Measurement Gate Fix

The one-time free measurement is no longer consumed when a measurement mode is opened.

New flow:
1. User opens GPS Walk, Draw on Map, or GPS + Adjust.
2. If there is no active subscription and the free measurement has not been used, access is allowed.
3. The free measurement is marked as used only after a new measurement is successfully saved from `FieldResultScreen`.
4. Cancelling/abandoning a measurement does not consume the free measurement.
5. Editing an existing saved field does not consume the free measurement.

This change is client-side only; the existing Vercel/Razorpay backend is unchanged.
