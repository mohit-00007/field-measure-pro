import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
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

// --------------------------------------------------
// CORS PREFLIGHT
// --------------------------------------------------
export function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

// --------------------------------------------------
// RAZORPAY API REQUEST WITH TIMEOUT
// --------------------------------------------------
async function razorpayFetch(subscriptionId) {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keyId || !keySecret) {
    throw new Error('Razorpay credentials are missing');
  }

  const controller = new AbortController();

  // Never allow Razorpay to hang the Vercel function.
  const timeout = setTimeout(() => {
    controller.abort();
  }, 8000);

  try {
    const credentials = Buffer.from(
      `${keyId}:${keySecret}`
    ).toString('base64');

    const response = await fetch(
      `https://api.razorpay.com/v1/subscriptions/${encodeURIComponent(
        subscriptionId
      )}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Basic ${credentials}`,
          Accept: 'application/json',
        },
        signal: controller.signal,
      }
    );

    const text = await response.text();

    let data;

    try {
      data = JSON.parse(text);
    } catch {
      data = {
        error: {
          description: text || 'Invalid Razorpay response',
        },
      };
    }

    if (!response.ok) {
      throw new Error(
        data?.error?.description ||
          `Razorpay API returned HTTP ${response.status}`
      );
    }

    return data;
  } finally {
    clearTimeout(timeout);
  }
}

// --------------------------------------------------
// GET SUBSCRIPTION STATUS
// --------------------------------------------------
export async function GET(req) {
  try {
    const url = new URL(req.url);
    const userId = String(
      url.searchParams.get('user_id') || ''
    ).trim();

    if (!userId) {
      return json(
        {
          active: false,
          status: 'error',
          error: 'user_id required',
        },
        400
      );
    }

    // --------------------------------------------------
    // GET LATEST SUBSCRIPTION FROM SUPABASE
    // --------------------------------------------------
    const { data, error } = await db()
      .from('fmp_subscriptions')
      .select(
        'id,user_id,email,plan,razorpay_subscription_id,status,current_period_end,created_at'
      )
      .eq('user_id', userId)
      .order('created_at', {
        ascending: false,
      })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error('SUPABASE STATUS ERROR:', error);

      return json(
        {
          active: false,
          status: 'error',
          error: 'Unable to read subscription status',
        },
        500
      );
    }

    // --------------------------------------------------
    // NO SUBSCRIPTION
    // --------------------------------------------------
    if (!data) {
      return json({
        active: false,
        status: 'none',
        plan: null,
        current_period_end: null,
      });
    }

    // --------------------------------------------------
    // IF DATABASE ALREADY KNOWS SUBSCRIPTION IS ACTIVE
    // DON'T MAKE A BLOCKING RAZORPAY REQUEST.
    // --------------------------------------------------
    if (
      data.status === 'active' ||
      data.status === 'authenticated'
    ) {
      return json({
        active: true,
        status: data.status,
        plan: data.plan,
        current_period_end: data.current_period_end || null,
      });
    }

    // --------------------------------------------------
    // IF WE DON'T HAVE A RAZORPAY SUBSCRIPTION ID
    // --------------------------------------------------
    if (!data.razorpay_subscription_id) {
      return json({
        active: false,
        status: data.status || 'created',
        plan: data.plan,
        current_period_end: data.current_period_end || null,
      });
    }

    // --------------------------------------------------
    // CHECK RAZORPAY
    // --------------------------------------------------
    try {
      const subscription = await razorpayFetch(
        data.razorpay_subscription_id
      );

      const razorpayStatus = subscription?.status || 'unknown';

      const active =
        razorpayStatus === 'active' ||
        razorpayStatus === 'authenticated';

      const currentPeriodEnd = subscription?.current_end
        ? new Date(
            Number(subscription.current_end) * 1000
          ).toISOString()
        : null;

      // --------------------------------------------------
      // UPDATE DATABASE
      // --------------------------------------------------
      const { error: updateError } = await db()
        .from('fmp_subscriptions')
        .update({
          status: razorpayStatus,
          current_period_end: currentPeriodEnd,
          updated_at: new Date().toISOString(),
        })
        .eq('id', data.id);

      if (updateError) {
        console.error(
          'SUPABASE STATUS UPDATE ERROR:',
          updateError
        );
      }

      return json({
        active,
        status: razorpayStatus,
        plan: data.plan,
        current_period_end: currentPeriodEnd,
      });
    } catch (razorpayError) {
      // --------------------------------------------------
      // IMPORTANT:
      // NEVER LET A RAZORPAY TIMEOUT CAUSE A 504.
      // Return the latest known database state.
      // --------------------------------------------------
      console.error(
        'RAZORPAY STATUS CHECK FAILED:',
        razorpayError?.message || razorpayError
      );

      const knownActive =
        data.status === 'active' ||
        data.status === 'authenticated';

      return json({
        active: knownActive,
        status: data.status || 'unknown',
        plan: data.plan,
        current_period_end:
          data.current_period_end || null,
        status_source: 'database',
      });
    }
  } catch (error) {
    console.error(
      'STATUS ENDPOINT ERROR:',
      error?.stack || error?.message || error
    );

    return json(
      {
        active: false,
        status: 'error',
        error:
          error?.message ||
          'Status check failed',
      },
      500
    );
  }
}