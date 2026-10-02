import Razorpay from 'razorpay';
import { createClient } from '@supabase/supabase-js';
const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','access-control-allow-origin':'*'}});
const db=()=>createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY);
export default async function handler(req){
 if(req.method!=='GET') return json({error:'Method not allowed'},405);
 try{
  const url=new URL(req.url); const userId=url.searchParams.get('user_id');
  if(!userId) return json({error:'user_id required'},400);
  const {data,error}=await db().from('fmp_subscriptions').select('*').eq('user_id',userId).order('created_at',{ascending:false}).limit(1).maybeSingle();
  if(error) throw error;
  if(!data) return json({active:false,status:'none'});
  const razorpay=new Razorpay({key_id:process.env.RAZORPAY_KEY_ID,key_secret:process.env.RAZORPAY_KEY_SECRET});
  const sub=await razorpay.subscriptions.fetch(data.razorpay_subscription_id);
  const active=['active','authenticated'].includes(sub.status);
  await db().from('fmp_subscriptions').update({status:sub.status,current_period_end:sub.current_end?new Date(sub.current_end*1000).toISOString():null,updated_at:new Date().toISOString()}).eq('id',data.id);
  return json({active,status:sub.status,plan:data.plan,current_period_end:sub.current_end?new Date(sub.current_end*1000).toISOString():null});
 }catch(e){console.error(e);return json({error:e?.message||'Status check failed'},500)}
}
