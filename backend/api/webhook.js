import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
const db=()=>createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY);
export default async function handler(req){
 if(req.method!=='POST') return new Response('Method not allowed',{status:405});
 const raw=await req.text();
 const sig=req.headers.get('x-razorpay-signature')||'';
 const expected=crypto.createHmac('sha256',process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest('hex');
 if(!sig || !crypto.timingSafeEqual(Buffer.from(expected),Buffer.from(sig))) return new Response('Invalid signature',{status:400});
 try{
  const event=JSON.parse(raw); const entity=event?.payload?.subscription?.entity;
  if(entity?.id){
   await db().from('fmp_subscriptions').update({status:entity.status,current_period_end:entity.current_end?new Date(entity.current_end*1000).toISOString():null,updated_at:new Date().toISOString()}).eq('razorpay_subscription_id',entity.id);
  }
  return new Response('ok');
 }catch(e){console.error(e);return new Response('Webhook error',{status:500})}
}
