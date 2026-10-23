import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

type ScriptureReference = {
  id: string;
  reference_key: string;
  human_reference: string;
  book_id: string;
  chapter: number;
  verse_start: number;
  verse_end: number | null;
  theme: string;
  fallback_text: string | null;
  fallback_translation: string | null;
  fallback_copyright: string | null;
};

type Devotional = {
  id: string;
  title: string;
  summary: string;
  reflection: string;
  practical_application: string;
  prayer: string;
  meditation_question: string;
  reading_plan: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const apiBibleBaseUrl =
  Deno.env.get("API_BIBLE_BASE_URL") ?? "https://rest.api.bible";
const apiBibleId = Deno.env.get("API_BIBLE_ID") ?? "41a6caa722a21d88-01";
const apiBibleName =
  Deno.env.get("API_BIBLE_NAME") ??
  "Biblia Sagrada, Nova Versao Transformadora";
const apiBibleAbbreviation = Deno.env.get("API_BIBLE_ABBREVIATION") ?? "NVT";

const localFallbackReference: ScriptureReference = {
  id: "local-fallback",
  reference_key: "JHN.3.16",
  human_reference: "Joao 3:16",
  book_id: "JHN",
  chapter: 3,
  verse_start: 16,
  verse_end: null,
  theme: "salvacao",
  fallback_text:
    "Pois Deus amou tanto o mundo, que deu o seu unico Filho, para que todos os que acreditam nele nao morram, mas tenham a vida eterna.",
  fallback_translation: "BLT",
  fallback_copyright: "Creative Commons Attribution-ShareAlike 4.0",
};

const localFallbackDevotional: Devotional = {
  id: "local-devotional",
  title: "Amor que nos encontra",
  summary: "Deus toma a iniciativa e chama a comunidade a responder com fe.",
  reflection:
    "O evangelho comeca no amor de Deus, nao na capacidade humana de merecer alguma coisa. Quando a igreja lembra isso, deixa de viver por medo e passa a servir por gratidao.",
  practical_application:
    "Hoje, identifica uma pessoa que precisa ouvir uma palavra simples de esperanca e aproxima-te com gentileza.",
  prayer:
    "Senhor, ajuda-nos a viver a partir do teu amor e a repartir essa graca com coragem.",
  meditation_question:
    "Como posso responder hoje ao amor de Deus de forma visivel?",
  reading_plan: "Joao 3; Romanos 5; Efesios 2",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
      db: { schema: "comunhao" },
    });

    const body = await readJsonBody(request);
    const churchId = typeof body.church_id === "string"
      ? body.church_id
      : typeof body.churchId === "string"
      ? body.churchId
      : null;

    const today = maputoDateKey();

    if (churchId) {
      const campaignContent = await findCampaignOverride(
        supabase,
        churchId,
        today,
      );
      if (campaignContent) {
        return jsonResponse(campaignContent);
      }
    }

    const cachedToday = await findContentForDate(supabase, today);
    if (cachedToday) {
      return jsonResponse({ ...cachedToday, source_status: "cache_today" });
    }

    const reference = await pickReference(supabase);
    const devotional = await pickDevotional(supabase, reference.theme);

    const scripture = await fetchApiBiblePassage(reference).catch((error) => {
      console.error("api_bible_unavailable", safeError(error));
      return null;
    });

    if (!scripture) {
      const latest = await findLatestValidContent(supabase);
      if (latest) {
        return jsonResponse({ ...latest, source_status: "cache_latest" });
      }
    }

    const content = await saveDailyContent({
      supabase,
      today,
      reference,
      devotional,
      scripture,
    });

    await markUsed(supabase, reference.id, devotional.id, today);
    return jsonResponse(content);
  } catch (error) {
    console.error("daily_scripture_engine_error", safeError(error));
    return jsonResponse(
      {
        error: "daily_scripture_engine_failed",
        message: "Nao foi possivel preparar o conteudo diario agora.",
      },
      500,
    );
  }
});

async function readJsonBody(request: Request): Promise<Record<string, unknown>> {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`missing_env_${name}`);
  }
  return value;
}

function maputoDateKey(): string {
  const formatted = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Maputo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return formatted;
}

async function findContentForDate(supabase: ReturnType<typeof createClient>, date: string) {
  const { data, error } = await supabase
    .from("daily_scripture_contents")
    .select("*")
    .eq("content_date", date)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function findLatestValidContent(supabase: ReturnType<typeof createClient>) {
  const { data, error } = await supabase
    .from("daily_scripture_contents")
    .select("*")
    .order("content_date", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function findCampaignOverride(
  supabase: ReturnType<typeof createClient>,
  churchId: string,
  today: string,
) {
  const { data, error } = await supabase
    .from("spiritual_campaign_contents")
    .select("*")
    .eq("church_id", churchId)
    .eq("active", true)
    .lte("starts_on", today)
    .gte("ends_on", today)
    .or(`content_date.is.null,content_date.eq.${today}`)
    .order("content_date", { ascending: false, nullsFirst: false })
    .order("priority", { ascending: false })
    .order("campaign_day", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  return {
    id: data.id,
    content_date: today,
    provider: "church_campaign",
    bible_id: null,
    bible_name: data.bible_name,
    bible_abbreviation: data.bible_abbreviation,
    reference_key: "church-campaign",
    reference_label: data.reference_label,
    book_id: null,
    chapter: null,
    verse_start: null,
    verse_end: null,
    scripture_text: data.scripture_text,
    copyright: data.copyright,
    theme: data.theme,
    devotional_title: data.title,
    devotional_summary: data.devotional_summary,
    devotional_reflection: data.devotional_reflection,
    practical_application: data.practical_application,
    prayer: data.prayer,
    meditation_question: data.meditation_question,
    reading_plan: data.reading_plan,
    source_status: "campaign_override",
    generated_at: new Date().toISOString(),
    metadata: {
      campaign: true,
      campaignName: data.campaign_name,
      campaignDay: data.campaign_day,
      churchId,
    },
  };
}

async function pickReference(
  supabase: ReturnType<typeof createClient>,
): Promise<ScriptureReference> {
  const { data, error } = await supabase
    .from("scripture_reference_library")
    .select("*")
    .eq("active", true)
    .order("last_used_at", { ascending: true, nullsFirst: true })
    .order("weight", { ascending: false })
    .limit(12);

  if (error) throw error;
  const rows = (data ?? []) as ScriptureReference[];
  if (rows.length === 0) return localFallbackReference;
  return rows[Math.floor(Math.random() * rows.length)];
}

async function pickDevotional(
  supabase: ReturnType<typeof createClient>,
  theme: string,
): Promise<Devotional> {
  const { data, error } = await supabase
    .from("daily_devotional_library")
    .select("*")
    .eq("active", true)
    .eq("theme", theme)
    .order("last_used_at", { ascending: true, nullsFirst: true })
    .limit(8);

  if (error) throw error;
  const rows = (data ?? []) as Devotional[];
  if (rows.length === 0) return localFallbackDevotional;
  return rows[Math.floor(Math.random() * rows.length)];
}

async function fetchApiBiblePassage(reference: ScriptureReference) {
  const apiKey = requiredEnv("API_BIBLE_KEY");
  const params = new URLSearchParams({
    "content-type": "text",
    "include-notes": "false",
    "include-titles": "false",
    "include-chapter-numbers": "false",
    "include-verse-numbers": "false",
  });
  const url = `${apiBibleBaseUrl}/v1/bibles/${apiBibleId}/passages/${reference.reference_key}?${params}`;

  for (let attempt = 1; attempt <= 2; attempt += 1) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 6500);
    try {
      const response = await fetch(url, {
        headers: { "api-key": apiKey },
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(`api_bible_http_${response.status}`);
      }
      const payload = await response.json();
      const data = payload.data;
      const text = normalizeText(data?.content ?? "");
      if (!text || !data?.reference) {
        throw new Error("api_bible_empty_content");
      }
      return {
        provider: "api_bible",
        bible_id: data.bibleId ?? apiBibleId,
        bible_name: apiBibleName,
        bible_abbreviation: apiBibleAbbreviation,
        reference_label: data.reference,
        scripture_text: text,
        copyright: data.copyright ?? null,
        source_status: "api_bible",
        metadata: {
          apiBible: true,
          fumsTokenPresent: Boolean(payload.meta?.fumsToken),
        },
      };
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

async function saveDailyContent(args: {
  supabase: ReturnType<typeof createClient>;
  today: string;
  reference: ScriptureReference;
  devotional: Devotional;
  scripture: Awaited<ReturnType<typeof fetchApiBiblePassage>> | null;
}) {
  const scripture =
    args.scripture ??
    {
      provider: "local_fallback",
      bible_id: null,
      bible_name: args.reference.fallback_translation ?? "Fallback local",
      bible_abbreviation: args.reference.fallback_translation ?? "LOCAL",
      reference_label: args.reference.human_reference,
      scripture_text:
        args.reference.fallback_text ?? localFallbackReference.fallback_text!,
      copyright:
        args.reference.fallback_copyright ??
        localFallbackReference.fallback_copyright,
      source_status: "local_fallback",
      metadata: { apiBible: false, fallback: true },
    };

  const row = {
    content_date: args.today,
    provider: scripture.provider,
    bible_id: scripture.bible_id,
    bible_name: scripture.bible_name,
    bible_abbreviation: scripture.bible_abbreviation,
    reference_key: args.reference.reference_key,
    reference_label: scripture.reference_label,
    book_id: args.reference.book_id,
    chapter: args.reference.chapter,
    verse_start: args.reference.verse_start,
    verse_end: args.reference.verse_end,
    scripture_text: scripture.scripture_text,
    copyright: scripture.copyright,
    theme: args.reference.theme,
    devotional_title: args.devotional.title,
    devotional_summary: args.devotional.summary,
    devotional_reflection: args.devotional.reflection,
    practical_application: args.devotional.practical_application,
    prayer: args.devotional.prayer,
    meditation_question: args.devotional.meditation_question,
    reading_plan: args.devotional.reading_plan,
    source_status: scripture.source_status,
    metadata: scripture.metadata,
  };

  const { data, error } = await args.supabase
    .from("daily_scripture_contents")
    .upsert(row, { onConflict: "content_date" })
    .select("*")
    .single();

  if (error) throw error;
  return data;
}

async function markUsed(
  supabase: ReturnType<typeof createClient>,
  referenceId: string,
  devotionalId: string,
  today: string,
) {
  if (referenceId !== "local-fallback") {
    await supabase
      .from("scripture_reference_library")
      .update({ last_used_at: today })
      .eq("id", referenceId);
  }
  if (devotionalId !== "local-devotional") {
    await supabase
      .from("daily_devotional_library")
      .update({ last_used_at: today })
      .eq("id", devotionalId);
  }
}

function normalizeText(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function safeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=300",
    },
  });
}
