import crypto from 'node:crypto';
import Razorpay from 'razorpay';
import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });

const db = () =>
  createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );

// ============================================================
// CORS PREFLIGHT
// ============================================================

export function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

// ============================================================
// VERIFY RAZORPAY SUBSCRIPTION
// ============================================================

export async function POST(req) {
  try {
    // --------------------------------------------------------
    // Parse request body
    // --------------------------------------------------------

    const body = await req.json();

    const razorpayPaymentId = String(
      body.razorpay_payment_id || ''
    ).trim();

    const razorpaySubscriptionId = String(
      body.razorpay_subscription_id || ''
    ).trim();

    const razorpaySignature = String(
      body.razorpay_signature || ''
    ).trim();

    const userId = String(
      body.user_id || ''
    ).trim();

    if (
      !razorpayPaymentId ||
      !razorpaySubscriptionId ||
      !razorpaySignature ||
      !userId
    ) {
      return json(
        {
          error: 'Missing verification fields',
        },
        400
      );
    }

    // --------------------------------------------------------
    // Check required environment variables
    // --------------------------------------------------------

    if (!process.env.RAZORPAY_KEY_SECRET) {
      console.error(
        'Missing RAZORPAY_KEY_SECRET'
      );

      return json(
        {
          error: 'Razorpay server configuration is missing',
        },
        500
      );
    }

    if (!process.env.RAZORPAY_KEY_ID) {
      console.error(
        'Missing RAZORPAY_KEY_ID'
      );

      return json(
        {
          error: 'Razorpay server configuration is missing',
        },
        500
      );
    }

    if (
      !process.env.SUPABASE_URL ||
      !process.env.SUPABASE_SERVICE_ROLE_KEY
    ) {
      console.error(
        'Missing Supabase server configuration'
      );

      return json(
        {
          error: 'Database server configuration is missing',
        },
        500
      );
    }

    // --------------------------------------------------------
    // Generate expected Razorpay signature
    // --------------------------------------------------------

    const signaturePayload =
      `${razorpayPaymentId}|${razorpaySubscriptionId}`;

    const expectedSignature = crypto
      .createHmac(
        'sha256',
        process.env.RAZORPAY_KEY_SECRET
      )
      .update(signaturePayload)
      .digest('hex');

    // --------------------------------------------------------
    // Timing-safe signature comparison
    // --------------------------------------------------------

    const expectedBuffer = Buffer.from(
      expectedSignature,
      'utf8'
    );

    const receivedBuffer = Buffer.from(
      razorpaySignature,
      'utf8'
    );

    if (
      expectedBuffer.length !==
      receivedBuffer.length
    ) {
      return json(
        {
          error: 'Invalid signature',
        },
        400
      );
    }

    if (
      !crypto.timingSafeEqual(
        expectedBuffer,
        receivedBuffer
      )
    ) {
      return json(
        {
          error: 'Invalid signature',
        },
        400
      );
    }

    // --------------------------------------------------------
    // Create Razorpay client
    // --------------------------------------------------------

    const razorpay = new Razorpay({
      key_id:
        process.env.RAZORPAY_KEY_ID,

      key_secret:
        process.env.RAZORPAY_KEY_SECRET,
    });

    // --------------------------------------------------------
    // Fetch subscription from Razorpay
    // --------------------------------------------------------

    const subscription =
      await razorpay.subscriptions.fetch(
        razorpaySubscriptionId
      );

    if (!subscription) {
      return json(
        {
          error: 'Subscription not found',
        },
        404
      );
    }

    // --------------------------------------------------------
    // Verify subscription ownership
    // --------------------------------------------------------

    const subscriptionUserId =
      subscription.notes?.user_id;

    if (
      subscriptionUserId &&
      String(subscriptionUserId) !==
        String(userId)
    ) {
      return json(
        {
          error: 'Subscription owner mismatch',
        },
        403
      );
    }

    // --------------------------------------------------------
    // Calculate current period end
    // --------------------------------------------------------

    const currentPeriodEnd =
      subscription.current_end
        ? new Date(
            Number(subscription.current_end) * 1000
          ).toISOString()
        : null;

    // --------------------------------------------------------
    // Determine active status
    // --------------------------------------------------------

    const active = [
      'active',
      'authenticated',
    ].includes(
      subscription.status
    );

    // --------------------------------------------------------
    // Update Supabase
    // --------------------------------------------------------

    const { error: dbError } =
      await db()
        .from('fmp_subscriptions')
        .update({
          status:
            subscription.status,

          current_period_end:
            currentPeriodEnd,

          updated_at:
            new Date().toISOString(),
        })
        .eq(
          'razorpay_subscription_id',
          razorpaySubscriptionId
        )
        .eq(
          'user_id',
          userId
        );

    if (dbError) {
      console.error(
        'SUPABASE UPDATE ERROR:',
        dbError
      );

      return json(
        {
          error:
            'Payment verified but database update failed',
        },
        500
      );
    }

    // --------------------------------------------------------
    // Success
    // --------------------------------------------------------

    return json({
      active,

      status:
        subscription.status,

      subscription_id:
        subscription.id,

      current_period_end:
        currentPeriodEnd,
    });

  } catch (error) {
    console.error(
      'VERIFY SUBSCRIPTION ERROR:',
      error
    );

    return json(
      {
        error:
          error?.error?.description ||
          error?.message ||
          'Verification failed',
      },
      500
    );
  }
}