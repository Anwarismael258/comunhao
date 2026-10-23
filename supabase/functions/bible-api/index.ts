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

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = requiredEnv("API_BIBLE_KEY");
    const body = await request.json().catch(() => ({}));
    const action = typeof body.action === "string" ? body.action : "books";

    if (action === "books") {
      const payload = await apiBibleFetch(apiKey, `/v1/bibles/${apiBibleId}/books`);
      return jsonResponse({
        bible: bibleMetadata(),
        books: (payload.data ?? []).map((book: Record<string, unknown>) => ({
          id: book.id,
          name: book.name,
          abbreviation: book.abbreviation,
        })),
      });
    }

    if (action === "chapters") {
      const bookId = requireString(body.book_id ?? body.bookId, "book_id");
      const payload = await apiBibleFetch(
        apiKey,
        `/v1/bibles/${apiBibleId}/books/${encodeURIComponent(bookId)}/chapters`,
      );
      return jsonResponse({
        bible: bibleMetadata(),
        chapters: (payload.data ?? []).map((chapter: Record<string, unknown>) => ({
          id: chapter.id,
          reference: chapter.reference,
          number: chapter.number,
        })),
      });
    }

    if (action === "passage") {
      const passageId = requireString(
        body.passage_id ?? body.passageId ?? body.chapter_id ?? body.chapterId,
        "passage_id",
      );
      const data = await fetchPassage(apiKey, passageId);
      return jsonResponse({
        bible: bibleMetadata(data),
        passage: passagePayload(data, passageId),
      });
    }

    if (action === "search") {
      const query = requireString(body.query, "query");
      const referenceId = referenceToPassageId(query);
      if (referenceId) {
        const data = await fetchPassage(apiKey, referenceId);
        const passage = passagePayload(data, referenceId);
        return jsonResponse({
          bible: bibleMetadata(data),
          query,
          results: passage.text ? [passage] : [],
          search_type: "reference",
        });
      }
      const params = new URLSearchParams({
        query,
        limit: "20",
        offset: "0",
        sort: "relevance",
      });
      const payload = await apiBibleFetch(
        apiKey,
        `/v1/bibles/${apiBibleId}/search?${params}`,
      );
      return jsonResponse({
        bible: bibleMetadata(),
        query,
        results: (payload.data?.verses ?? payload.data?.passages ?? []).map(
          (item: Record<string, unknown>) => ({
            id: item.id,
            reference: item.reference,
            text: normalizeText(item.text ?? item.content ?? ""),
          }),
        ),
      });
    }

    return jsonResponse({ error: "unknown_action" }, 400);
  } catch (error) {
    console.error("bible_api_error", safeError(error));
    return jsonResponse(
      {
        error: "bible_api_unavailable",
        message: "Nao foi possivel carregar a Biblia agora.",
      },
      200,
    );
  }
});

async function apiBibleFetch(apiKey: string, path: string) {
  const response = await fetch(`${apiBibleBaseUrl}${path}`, {
    headers: { "api-key": apiKey },
  });
  if (!response.ok) {
    throw new Error(`api_bible_http_${response.status}`);
  }
  return await response.json();
}

async function fetchPassage(apiKey: string, passageId: string) {
  const params = new URLSearchParams({
    "content-type": "text",
    "include-notes": "false",
    "include-titles": "true",
    "include-chapter-numbers": "false",
    "include-verse-numbers": "true",
  });
  const payload = await apiBibleFetch(
    apiKey,
    `/v1/bibles/${apiBibleId}/passages/${encodeURIComponent(passageId)}?${params}`,
  );
  return payload.data ?? {};
}

function passagePayload(data: Record<string, unknown>, fallbackId: string) {
  return {
    id: data.id ?? fallbackId,
    reference: data.reference ?? fallbackId,
    text: normalizeText(data.content ?? ""),
    copyright: data.copyright ?? null,
  };
}

function bibleMetadata(data: Record<string, unknown> = {}) {
  return {
    id: data.bibleId ?? apiBibleId,
    name: apiBibleName,
    abbreviation: apiBibleAbbreviation,
  };
}

function normalizeText(value: unknown) {
  return String(value ?? "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function referenceToPassageId(query: string) {
  const normalized = normalizeReference(query);
  const match = normalized.match(/^([1-3]?\s*[a-z ]+?)\s+(\d{1,3})(?::(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?)?$/);
  if (!match) return null;
  const book = bookIdFor(match[1]);
  if (!book) return null;
  const chapter = match[2];
  const verse = match[3];
  const endVerse = match[4];
  if (!verse) return `${book}.${chapter}`;
  if (endVerse && endVerse !== verse) {
    return `${book}.${chapter}.${verse}-${book}.${chapter}.${endVerse}`;
  }
  return `${book}.${chapter}.${verse}`;
}

function normalizeReference(value: string) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/[.]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function bookIdFor(rawBook: string) {
  const book = rawBook.replace(/\s+/g, " ").trim();
  const books: Record<string, string> = {
    genesis: "GEN",
    gen: "GEN",
    exodo: "EXO",
    levitico: "LEV",
    numeros: "NUM",
    deuteronomio: "DEU",
    josue: "JOS",
    juizes: "JDG",
    rute: "RUT",
    "1 samuel": "1SA",
    "2 samuel": "2SA",
    "1 reis": "1KI",
    "2 reis": "2KI",
    "1 cronicas": "1CH",
    "2 cronicas": "2CH",
    esdras: "EZR",
    neemias: "NEH",
    ester: "EST",
    jo: "JOB",
    salmos: "PSA",
    salmo: "PSA",
    proverbios: "PRO",
    eclesiastes: "ECC",
    cantares: "SNG",
    isaias: "ISA",
    jeremias: "JER",
    lamentacoes: "LAM",
    ezequiel: "EZK",
    daniel: "DAN",
    oseias: "HOS",
    joel: "JOL",
    amos: "AMO",
    obadias: "OBA",
    jonas: "JON",
    miqueias: "MIC",
    naum: "NAM",
    habacuque: "HAB",
    sofonias: "ZEP",
    ageu: "HAG",
    zacarias: "ZEC",
    malaquias: "MAL",
    mateus: "MAT",
    marcos: "MRK",
    lucas: "LUK",
    joao: "JHN",
    atos: "ACT",
    romanos: "ROM",
    "1 corintios": "1CO",
    "2 corintios": "2CO",
    galatas: "GAL",
    efesios: "EPH",
    filipenses: "PHP",
    colossenses: "COL",
    "1 tessalonicenses": "1TH",
    "2 tessalonicenses": "2TH",
    "1 timoteo": "1TI",
    "2 timoteo": "2TI",
    tito: "TIT",
    filemom: "PHM",
    hebreus: "HEB",
    tiago: "JAS",
    "1 pedro": "1PE",
    "2 pedro": "2PE",
    "1 joao": "1JN",
    "2 joao": "2JN",
    "3 joao": "3JN",
    judas: "JUD",
    apocalipse: "REV",
  };
  return books[book] ?? null;
}

function requireString(value: unknown, name: string) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${name}_required`);
  }
  return value.trim();
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name}_missing`);
  return value;
}

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function safeError(error: unknown) {
  return error instanceof Error
    ? { name: error.name, message: error.message }
    : { message: String(error) };
}
