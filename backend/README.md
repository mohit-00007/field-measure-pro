# Field Measure Pro — Razorpay subscription backend

The Flutter Web app is hosted on GitHub Pages. Payment secrets must live on a server. This backend is written for Vercel Functions and uses Razorpay Subscriptions + UPI AutoPay and Supabase for subscription records.

Razorpay supports monthly/yearly plans and recurring UPI AutoPay. The current Razorpay documentation also recommends server-side handling of secrets and webhook signature validation. See the official docs linked from the root project README.

## Setup

### 1. Create a Supabase project
Run `schema.sql` in Supabase SQL Editor. Copy the project URL and service-role key into server environment variables. Never expose the service-role key to Flutter/GitHub Pages.

### 2. Create Razorpay plans
Generate live/test API credentials in Razorpay. Then from this folder run:

```bash
npm install
RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=... node create-plans.mjs
```

On Windows PowerShell:

```powershell
$env:RAZORPAY_KEY_ID='rzp_test_...'
$env:RAZORPAY_KEY_SECRET='...'
node create-plans.mjs
```

Copy the returned monthly/yearly plan IDs into the Vercel environment variables.

### 3. Deploy backend to Vercel
Create a Vercel project pointing at this `backend` folder. Add:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_MONTHLY_PLAN_ID`
- `RAZORPAY_YEARLY_PLAN_ID`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RAZORPAY_WEBHOOK_SECRET`

Deploy and note the HTTPS URL, for example `https://field-measure-pro-api.vercel.app`.

### 4. Configure Razorpay webhook
Set a webhook URL:

`https://YOUR-BACKEND-DOMAIN/api/webhook`

Use the same webhook secret. Subscribe to the subscription lifecycle events offered by your Razorpay dashboard, especially activation, pause/cancel, and charge-related events.

### 5. Connect GitHub Pages to the backend
The Flutter workflow reads the repository variable `FMP_API_BASE_URL` and passes it as a Dart define. In GitHub:

Settings → Secrets and variables → Actions → Variables → New repository variable

Name: `FMP_API_BASE_URL`
Value: `https://YOUR-BACKEND-DOMAIN`

Do not put the Razorpay secret or Supabase service-role key in GitHub variables or Flutter source.

### Trial behavior
The current app gives one measurement per browser profile, then shows the ₹99/month and ₹990/year paywall. This is a UX-level trial gate. For strict anti-abuse enforcement across browsers/devices, add authenticated user accounts and store the trial entitlement server-side before launch.
