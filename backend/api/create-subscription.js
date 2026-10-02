import Razorpay from 'razorpay';
import { createClient } from '@supabase/supabase-js';

const json = (data, status=200) => new Response(JSON.stringify(data), {status, headers:{'content-type':'application/json','access-control-allow-origin':'*'}});
const db = () => createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

export default async function handler(req) {
  if (req.method !== 'POST') return json({error:'Method not allowed'},405);
  try {
    const body = await req.json();
    const plan = body.plan === 'yearly' ? 'yearly' : body.plan === 'monthly' ? 'monthly' : null;
    const userId = String(body.user_id || '').trim();
    const email = String(body.email || '').trim();
    if (!plan || !userId || !email) return json({error:'plan, user_id and email are required'},400);

    const planId = plan === 'monthly' ? process.env.RAZORPAY_MONTHLY_PLAN_ID : process.env.RAZORPAY_YEARLY_PLAN_ID;
    if (!planId) return json({error:`Missing Razorpay ${plan} plan ID`},500);

    const razorpay = new Razorpay({key_id:process.env.RAZORPAY_KEY_ID,key_secret:process.env.RAZORPAY_KEY_SECRET});
    const subscription = await razorpay.subscriptions.create({
      plan_id: planId,
      total_count: plan === 'monthly' ? 120 : 10,
      customer_notify: 1,
      notes: {product:'Field Measure Pro', user_id:userId, email}
    });

    const {error} = await db().from('fmp_subscriptions').insert({
      user_id:userId,email,plan,razorpay_subscription_id:subscription.id,status:subscription.status || 'created'
    });
    if (error) throw error;

    return json({
      key_id:process.env.RAZORPAY_KEY_ID,
      subscription_id:subscription.id,
      plan,
      amount:plan==='monthly'?99:990,
      currency:'INR'
    });
  } catch (e) {
    console.error(e);
    return json({error:e?.error?.description || e?.message || 'Unable to create subscription'},500);
  }
}
