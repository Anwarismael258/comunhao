import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type InternalNotification = {
  id: string;
  recipient_profile_id: string;
  title: string;
  message: string;
  notification_type: string;
  reference_table: string | null;
  reference_id: string | null;
  action_route: string | null;
  priority: string | null;
  metadata: Record<string, unknown> | null;
};

type PushToken = {
  id: string;
  token: string;
  app_code: string;
  platform: string | null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let notificationId: string | null = null;

  try {
    const body = await readJsonBody(request);
    notificationId = readString(body.notification_id) ??
      readString(body.notificationId) ??
      readString(body.record?.id);

    if (!notificationId) {
      return jsonResponse({ error: "missing_notification_id" }, 400);
    }

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false },
        db: { schema: "comunhao" },
      },
    );

    const { data: notification, error: notificationError } = await supabase
      .from("internal_notifications")
      .select("*")
      .eq("id", notificationId)
      .maybeSingle<InternalNotification>();

    if (notificationError) throw notificationError;
    if (!notification) {
      return jsonResponse({ error: "notification_not_found" }, 404);
    }

    const { data: tokens, error: tokenError } = await supabase
      .from("push_device_tokens")
      .select("id, token, app_code, platform")
      .eq("profile_id", notification.recipient_profile_id);

    if (tokenError) throw tokenError;

    const activeTokens = (tokens ?? [])
      .map((item) => item as PushToken)
      .filter((item) => item.token && item.token.trim().length > 0);

    if (activeTokens.length === 0) {
      await markAttempt(
        supabase,
        notification.id,
        "skipped",
        "firebase",
        "No push token registered for this user.",
      );
      return jsonResponse({ ok: true, sent: 0, skipped: "no_tokens" });
    }

    let sent = 0;
    const failures: string[] = [];
    const firebaseByApp = new Map<string, {
      accessToken: string;
      projectId: string;
    }>();
    for (const token of activeTokens) {
      const appCode = normalizeAppCode(token.app_code);
      let firebase = firebaseByApp.get(appCode);
      if (!firebase) {
        firebase = await firebaseAccessToken(appCode);
        firebaseByApp.set(appCode, firebase);
      }
      const result = await sendFirebaseMessage({
        accessToken: firebase.accessToken,
        projectId: firebase.projectId,
        token: token.token,
        notification,
      });
      if (result.ok) {
        sent += 1;
      } else {
        failures.push(`${token.id}:${result.error}`);
      }
    }

    await markAttempt(
      supabase,
      notification.id,
      failures.length === 0 ? "sent" : sent > 0 ? "partial" : "failed",
      "firebase",
      failures.join("; ").slice(0, 1000) || null,
    );

    return jsonResponse({ ok: true, sent, failed: failures.length });
  } catch (error) {
    console.error("send_push_notification_error", safeError(error));
    if (notificationId) {
      try {
        const supabase = createClient(
          requiredEnv("SUPABASE_URL"),
          requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
          {
            auth: { persistSession: false },
            db: { schema: "comunhao" },
          },
        );
        await markAttempt(
          supabase,
          notificationId,
          "failed",
          "firebase",
          safeError(error),
        );
      } catch (_) {
        // Best effort only.
      }
    }
    return jsonResponse(
      { error: "push_dispatch_failed", message: safeError(error) },
      500,
    );
  }
});

async function readJsonBody(request: Request): Promise<Record<string, any>> {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

function readString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing_env_${name}`);
  return value;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch (_) {
    return String(error);
  }
}

async function markAttempt(
  supabase: ReturnType<typeof createClient>,
  notificationId: string,
  status: string,
  provider: string,
  lastError: string | null,
) {
  const sentAt = status === "sent" || status === "partial"
    ? new Date().toISOString()
    : null;
  const deliveredAt = status === "sent" ? new Date().toISOString() : null;
  const { data: existingRows } = await supabase
    .from("notification_delivery_attempts")
    .select("id, attempt_count")
    .eq("notification_id", notificationId)
    .eq("channel", "push")
    .or("provider.is.null,provider.eq.firebase")
    .limit(1);

  const existing = Array.isArray(existingRows) && existingRows.length > 0
    ? existingRows[0] as { id: string; attempt_count: number | null }
    : null;

  if (existing) {
    await supabase.from("notification_delivery_attempts").update({
      provider,
      delivery_status: status,
      attempt_count: (existing.attempt_count ?? 0) + 1,
      sent_at: sentAt,
      delivered_at: deliveredAt,
      last_error: lastError,
    }).eq("id", existing.id);
    return;
  }

  await supabase.from("notification_delivery_attempts").insert({
    notification_id: notificationId,
    channel: "push",
    provider,
    delivery_status: status,
    attempt_count: 1,
    sent_at: sentAt,
    delivered_at: deliveredAt,
    last_error: lastError,
  });
}

async function firebaseAccessToken(appCode: string): Promise<{
  accessToken: string;
  projectId: string;
}> {
  const appSecretName =
    `FIREBASE_SERVICE_ACCOUNT_${appCode.toUpperCase()}_JSON`;
  const raw = Deno.env.get(appSecretName) ??
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error(`missing_env_${appSecretName}`);
  }
  const serviceAccount = JSON.parse(raw);
  const clientEmail = readString(serviceAccount.client_email);
  const privateKey = readString(serviceAccount.private_key);
  const projectId = readString(serviceAccount.project_id);
  if (!clientEmail || !privateKey || !projectId) {
    throw new Error("invalid_firebase_service_account_json");
  }

  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = base64UrlJson({ alg: "RS256", typ: "JWT" });
  const jwtPayload = base64UrlJson({
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });
  const unsignedJwt = `${jwtHeader}.${jwtPayload}`;
  const signature = await signJwt(unsignedJwt, privateKey);
  const assertion = `${unsignedJwt}.${signature}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const tokenBody = await response.json();
  if (!response.ok) {
    throw new Error(`firebase_oauth_failed:${JSON.stringify(tokenBody)}`);
  }
  const accessToken = readString(tokenBody.access_token);
  if (!accessToken) throw new Error("firebase_oauth_missing_access_token");
  return { accessToken, projectId };
}

function normalizeAppCode(value: string): string {
  const normalized = value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_");
  return normalized || "comunhao";
}

async function sendFirebaseMessage({
  accessToken,
  projectId,
  token,
  notification,
}: {
  accessToken: string;
  projectId: string;
  token: string;
  notification: InternalNotification;
}): Promise<{ ok: true } | { ok: false; error: string }> {
  const data = sanitizeData({
    notification_id: notification.id,
    notification_type: notification.notification_type,
    reference_table: notification.reference_table,
    reference_id: notification.reference_id,
    action_route: notification.action_route,
    priority: notification.priority ?? "normal",
    metadata: JSON.stringify(notification.metadata ?? {}),
  });

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notification.title,
            body: notification.message,
          },
          data,
          android: {
            priority: "HIGH",
            notification: {
              sound: "default",
              default_sound: true,
              notification_priority: "PRIORITY_HIGH",
            },
          },
        },
      }),
    },
  );

  if (response.ok) return { ok: true };
  return { ok: false, error: await response.text() };
}

function sanitizeData(input: Record<string, unknown>): Record<string, string> {
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(input)) {
    if (value == null) continue;
    data[key] = String(value).slice(0, 1000);
  }
  return data;
}

function base64UrlJson(value: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

async function signJwt(unsignedJwt: string, privateKeyPem: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedJwt),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}
