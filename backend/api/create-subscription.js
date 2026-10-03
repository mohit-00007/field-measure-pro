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

// --------------------------------------------------
// CORS
// --------------------------------------------------
export function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}

// --------------------------------------------------
// POST
// --------------------------------------------------
export async function POST(req) {
  try {
    // --------------------------------------------------
    // READ RAW BODY FIRST
    // --------------------------------------------------
    const rawBody = await req.text();

    console.log('CREATE SUBSCRIPTION RAW BODY:', rawBody);

    if (!rawBody || !rawBody.trim()) {
      return json(
        {
          error: 'Request body is empty',
        },
        400
      );
    }

    // --------------------------------------------------
    // PARSE JSON
    // --------------------------------------------------
    let body;

    try {
      body = JSON.parse(rawBody);
    } catch (parseError) {
      console.error(
        'JSON PARSE ERROR:',
        parseError?.message
      );

      return json(
        {
          error: 'Invalid JSON request body',
          details: parseError?.message,
          received: rawBody.substring(0, 500),
        },
        400
      );
    }

    // --------------------------------------------------
    // VALIDATE INPUT
    // --------------------------------------------------
    const plan =
      body.plan === 'yearly'
        ? 'yearly'
        : body.plan === 'monthly'
          ? 'monthly'
          : null;

    const userId = String(
      body.user_id || ''
    ).trim();

    const email = String(
      body.email || ''
    ).trim();

    if (!plan || !userId || !email) {
      return json(
        {
          error:
            'plan, user_id and email are required',
        },
        400
      );
    }

    // --------------------------------------------------
    // SELECT RAZORPAY PLAN
    // --------------------------------------------------
    const planId =
      plan === 'monthly'
        ? process.env.RAZORPAY_MONTHLY_PLAN_ID
        : process.env.RAZORPAY_YEARLY_PLAN_ID;

    if (!planId) {
      return json(
        {
          error:
            `Missing Razorpay ${plan} plan ID`,
        },
        500
      );
    }

    // --------------------------------------------------
    // CHECK REQUIRED ENVIRONMENT VARIABLES
    // --------------------------------------------------
    if (
      !process.env.RAZORPAY_KEY_ID ||
      !process.env.RAZORPAY_KEY_SECRET
    ) {
      return json(
        {
          error:
            'Razorpay credentials are not configured',
        },
        500
      );
    }

    if (
      !process.env.SUPABASE_URL ||
      !process.env.SUPABASE_SERVICE_ROLE_KEY
    ) {
      return json(
        {
          error:
            'Supabase environment variables are not configured',
        },
        500
      );
    }

    // --------------------------------------------------
    // RAZORPAY CLIENT
    // --------------------------------------------------
    const razorpay = new Razorpay({
      key_id:
        process.env.RAZORPAY_KEY_ID,

      key_secret:
        process.env.RAZORPAY_KEY_SECRET,
    });

    // --------------------------------------------------
    // CREATE SUBSCRIPTION
    // --------------------------------------------------
    console.log(
      'Creating Razorpay subscription:',
      {
        plan,
        planId,
        userId,
        email,
      }
    );

    const subscription =
      await razorpay.subscriptions.create({
        plan_id: planId,

        total_count:
          plan === 'monthly'
            ? 120
            : 10,

        customer_notify: 1,

        notes: {
          product:
            'Field Measure Pro',

          user_id:
            userId,

          email,
        },
      });

    console.log(
      'Razorpay subscription created:',
      subscription.id
    );

    // --------------------------------------------------
    // SAVE IN SUPABASE
    // --------------------------------------------------
    const { error } =
      await db()
        .from('fmp_subscriptions')
        .insert({
          user_id:
            userId,

          email,

          plan,

          razorpay_subscription_id:
            subscription.id,

          status:
            subscription.status ||
            'created',
        });

    if (error) {
      console.error(
        'SUPABASE INSERT ERROR:',
        error
      );

      return json(
        {
          error:
            'Subscription was created in Razorpay, but saving it to the database failed',
          details:
            error.message,
        },
        500
      );
    }

    // --------------------------------------------------
    // SUCCESS
    // --------------------------------------------------
    return json({
      key_id:
        process.env.RAZORPAY_KEY_ID,

      subscription_id:
        subscription.id,

      plan,

      amount:
        plan === 'monthly'
          ? 99
          : 990,

      currency:
        'INR',
    });
  } catch (e) {
    console.error(
      'CREATE SUBSCRIPTION ERROR:',
      e?.stack ||
        e?.message ||
        e
    );

    return json(
      {
        error:
          e?.error?.description ||
          e?.message ||
          'Unable to create subscription',
      },
      500
    );
  }
}