# Field Measure Pro Payments

Pricing:
- Monthly: ₹99/month
- Yearly: ₹990/year (₹198 less than 12 monthly payments)

The web app uses Razorpay Checkout for subscription signup and Razorpay Subscriptions/UPI AutoPay for recurring billing. The browser never receives the Razorpay secret.

## Required setup before payment can work

1. Create a Razorpay account and complete merchant onboarding/KYC as required by Razorpay.
2. Enable/activate Subscriptions and UPI AutoPay for the account. Availability depends on merchant eligibility/configuration.
3. Create the monthly ₹99 and yearly ₹990 plans. The `backend/create-plans.mjs` helper can create them.
4. Deploy `backend/` to Vercel and configure its environment variables.
5. Create a Supabase project and run `backend/schema.sql`.
6. Configure the Razorpay webhook to `https://YOUR-BACKEND/api/webhook`.
7. In GitHub repository Settings → Secrets and variables → Actions → Variables, create `FMP_API_BASE_URL` with the backend HTTPS URL.
8. Keep the existing `GOOGLE_MAPS_API_KEY` secret for Google Maps.
9. Push `main`; GitHub Actions builds Flutter Web with the backend URL.

## Security

Never put `RAZORPAY_KEY_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`, or `RAZORPAY_WEBHOOK_SECRET` in Flutter, `web/`, GitHub Pages, or client-side JavaScript. Only the public Razorpay Key ID is returned to Checkout.

The backend verifies the Razorpay checkout signature and validates webhook signatures before updating subscription state.
