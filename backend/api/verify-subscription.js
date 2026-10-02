import crypto from 'node:crypto';
import Razorpay from 'razorpay';
import { createClient } from '@supabase/supabase-js';
const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','access-control-allow-origin':'*'}});
const db=()=>createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY);
export default async function handler(req){
 if(req.method!=='POST') return json({error:'Method not allowed'},405);
 try{
  const b=await req.json(); const {razorpay_payment_id,razorpay_subscription_id,razorpay_signature,user_id}=b;
  if(!razorpay_payment_id||!razorpay_subscription_id||!razorpay_signature||!user_id) return json({error:'Missing verification fields'},400);
  const expected=crypto.createHmac('sha256',process.env.RAZORPAY_KEY_SECRET).update(`${razorpay_payment_id}|${razorpay_subscription_id}`).digest('hex');
  if(!crypto.timingSafeEqual(Buffer.from(expected),Buffer.from(razorpay_signature))) return json({error:'Invalid signature'},400);
  const razorpay=new Razorpay({key_id:process.env.RAZORPAY_KEY_ID,key_secret:process.env.RAZORPAY_KEY_SECRET});
  const sub=await razorpay.subscriptions.fetch(razorpay_subscription_id);
  if(sub.notes?.user_id && String(sub.notes.user_id)!==String(user_id)) return json({error:'Subscription owner mismatch'},403);
  await db().from('fmp_subscriptions').update({status:sub.status,current_period_end:sub.current_end?new Date(sub.current_end*1000).toISOString():null,updated_at:new Date().toISOString()}).eq('razorpay_subscription_id',razorpay_subscription_id).eq('user_id',user_id);
  return json({active:['active','authenticated'].includes(sub.status),status:sub.status,subscription_id:sub.id,current_period_end:sub.current_end?new Date(sub.current_end*1000).toISOString():null});
 }catch(e){console.error(e);return json({error:e?.message||'Verification failed'},500)}
}
