import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("OK", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const client = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: { user } } = await client.auth.getUser(token);
  if (!user) return json({ error: "unauthorized" }, 401);
  const body = await req.json().catch(() => ({}));
  const amount = Number(body.amount);
  const provider = String(body.provider || "").toLowerCase();
  const phone = String(body.phone_number || user.phone || "").trim();
  if (!Number.isFinite(amount) || amount <= 0 || !["mpesa", "emola"].includes(provider) || !phone) return json({ error: "invalid_payment_arguments" }, 400);
  const reference = `COM${Date.now()}`;
  const apiToken = Deno.env.get("PAYSUITE_API_TOKEN") || "";
  if (!apiToken) return json({ error: "paysuite_not_configured" }, 503);
  const baseUrl = (Deno.env.get("PAYSUITE_BASE_URL") || "https://paysuite.tech").replace(/\/$/, "");
  const callbackUrl = `${supabaseUrl}/functions/v1/paysuite-webhook`;
  const response = await fetch(`${baseUrl}/api/v1/payments`, { method: "POST", headers: { Authorization: `Bearer ${apiToken}`, "Content-Type": "application/json", Accept: "application/json" }, body: JSON.stringify({ amount, method: provider, reference, description: String(body.description || `Comunhao ${reference}`), customer_phone: phone, callback_url: callbackUrl }) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) return json({ error: data.message || data.error || "paysuite_payment_failed", reference }, 502);
  const payment = data?.data ?? data;
  return json({ success: true, reference, status: payment?.status || "pending", checkout_url: payment?.checkout_url || payment?.payment_link || null });
});
