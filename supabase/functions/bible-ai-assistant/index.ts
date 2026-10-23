const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AssistantMode =
  | "explain"
  | "study"
  | "cell"
  | "sermon"
  | "question"
  | "devotional"
  | "reading_plan"
  | "prayer"
  | "counsel";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let body: Record<string, unknown> = {};
  try {
    body = await request.json().catch(() => ({}));
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return jsonResponse(
        {
          answer:
            "O Assistente Biblico IA ainda nao esta configurado no backend. Defina GEMINI_API_KEY nos Supabase Secrets.",
          configured: false,
        },
        200,
      );
    }

    const question = typeof body.question === "string"
      ? body.question.trim()
      : "";
    const mode = normalizeMode(body.mode);
    const churchName = typeof body.church_name === "string"
      ? body.church_name
      : "Comunhao";

    if (question.length < 3) {
      return jsonResponse({ error: "question_required" }, 400);
    }

    const prompt = buildPrompt({ question, mode, churchName });
    const answer = await askGemini(apiKey, prompt);
    return jsonResponse({
      answer,
      mode,
      configured: true,
    });
  } catch (error) {
    console.error("bible_ai_assistant_error", safeError(error));
    const mode = normalizeMode(body?.mode);
    const question = typeof body?.question === "string" ? body.question : "";
    return jsonResponse(
      {
        answer: fallbackAnswer({ mode, question }),
        configured: true,
      },
      200,
    );
  }
});

function normalizeMode(value: unknown): AssistantMode {
  const raw = typeof value === "string" ? value : "question";
  const allowed = new Set([
    "explain",
    "study",
    "cell",
    "sermon",
    "question",
    "devotional",
    "reading_plan",
    "prayer",
    "counsel",
  ]);
  return allowed.has(raw) ? raw as AssistantMode : "question";
}

function fallbackAnswer(input: { mode: AssistantMode; question: string }) {
  const theme = input.question.trim() || "a sua pergunta";
  const templates: Record<AssistantMode, string> = {
    explain: `Explicacao biblica sobre "${theme}":

1. Contexto: leia a passagem completa e observe quem fala, a quem fala e qual situacao esta a ser tratada.
2. Significado: procure a ideia principal do texto antes de tirar conclusoes isoladas.
3. Aplicacao: transforme a mensagem em uma atitude pratica de fe, amor, arrependimento, perdao ou obediencia.
4. Referencias relacionadas: compare com textos do mesmo tema e converse com um lider da igreja quando a duvida for sensivel.`,
    study: `Estudo biblico sobre "${theme}":

Tema: crescimento espiritual com base na Palavra.
Objetivo: ajudar o grupo a compreender, dialogar e aplicar a verdade biblica.
Leitura principal: escolha uma passagem central relacionada ao tema.
Pontos principais:
1. O que o texto revela sobre Deus.
2. O que o texto revela sobre o ser humano.
3. Que resposta pratica o texto pede.
Perguntas: O que mais chama atencao? Que atitude precisa mudar? Como podemos praticar isto esta semana?
Oracao final: peca direcao, humildade e obediencia.`,
    cell: `Estudo para celula sobre "${theme}":

Quebra-gelo: partilhe uma experiencia simples relacionada ao tema.
Leitura biblica: escolha uma passagem curta.
Explicacao: apresente a ideia principal em linguagem simples.
Perguntas: O que aprendemos? Onde isto toca a nossa vida? Como podemos apoiar uns aos outros?
Dinamica opcional: cada pessoa escreve uma aplicacao pratica para a semana.
Oracao: ore por forca para viver a Palavra.`,
    sermon: `Esboco pastoral sobre "${theme}":

Titulo: Uma Palavra para Viver com Fidelidade.
Texto base: escolha a passagem central.
Introducao: apresente a dor, pergunta ou necessidade que o texto responde.
Ponto 1: Deus chama o seu povo a ouvir.
Ponto 2: A fe verdadeira produz obediencia pratica.
Ponto 3: A graca de Deus sustenta a caminhada.
Aplicacao: convide a igreja a responder com arrependimento, confianca e servico.
Conclusao: termine com esperanca e oracao.`,
    question: `Resposta biblica sobre "${theme}":

A melhor forma de responder e partir do texto biblico, olhar o contexto e aplicar com equilibrio. A Biblia deve ser lida com humildade, evitando tirar uma frase do seu contexto. Quando a pergunta envolver decisao importante, sofrimento, conflito familiar ou aconselhamento, procure tambem o pastor ou um lider maduro da sua igreja.`,
    devotional: `Devocional diario:

Versiculo: escolha uma passagem curta relacionada a "${theme}".
Contexto: Deus fala ao coracao humano dentro de uma historia real.
Reflexao: a fe cresce quando ouvimos a Palavra e damos o proximo passo com obediencia.
Aplicacao: hoje pratique uma atitude concreta relacionada ao tema.
Oracao: Senhor, guia-me pela tua Palavra e ajuda-me a viver com sabedoria.
Desafio: encoraje alguem com uma mensagem de fe hoje.`,
    reading_plan: `Plano de leitura para "${theme}":

Dia 1: leia uma passagem introdutoria sobre o tema.
Dia 2: leia um salmo ou evangelho relacionado.
Dia 3: leia uma carta apostolica que aplique o tema.
Dia 4: escreva um resumo do que aprendeu.
Dia 5: partilhe uma aplicacao com alguem.
Se atrasar, retome no dia atual sem culpa e continue com constancia.`,
    prayer: `Oracao:

Senhor, apresento diante de ti esta situacao: ${theme}. Dá-me sabedoria, paz e coragem para agir com amor e verdade. Ajuda-me a ouvir a tua Palavra, procurar bons conselhos e caminhar com humildade. Fortalece o meu coracao e guia os meus passos. Amem.`,
    counsel: `Aconselhamento biblico geral sobre "${theme}":

1. Leve a situacao a Deus em oracao.
2. Procure passagens que falem de sabedoria, paciencia, perdao, verdade e amor.
3. Evite decidir no impulso quando estiver ferido ou ansioso.
4. Converse com o pastor ou um lider maduro da igreja.
5. Se envolver saude mental, abuso, violencia, risco pessoal ou sofrimento profundo, procure ajuda profissional e apoio local imediato.`,
  };
  return templates[input.mode] ?? templates.question;
}

function buildPrompt(input: {
  question: string;
  mode: AssistantMode;
  churchName: string;
}) {
  const moduleInstruction = {
    explain:
      "Explique a passagem com contexto historico, significado, aplicacao pratica e referencias relacionadas.",
    study:
      "Crie um estudo biblico com tema, objetivo, leitura principal, introducao, pontos, perguntas, aplicacao e oracao final.",
    cell:
      "Crie um estudo para celula de 30 minutos com quebra-gelo, leitura, explicacao, perguntas, dinamica opcional e oracao.",
    sermon:
      "Crie apoio ao pastor com titulo, texto base, introducao, 3 ou 4 pontos principais, aplicacao e conclusao.",
    question:
      "Responda a pergunta biblica com clareza, referencias e aplicacao simples.",
    devotional:
      "Crie um devocional diario com versiculo, contexto, reflexao, aplicacao, oracao e desafio do dia.",
    reading_plan:
      "Ajude no plano de leitura com acompanhamento, incentivo, atrasos e resumo dos capitulos citados.",
    prayer:
      "Escreva uma oracao respeitosa baseada em principios biblicos, sem afirmar falar em nome de Deus.",
    counsel:
      "Ofereca aconselhamento biblico pastoral geral, indique passagens relevantes e recomende conversa com lider/pastor ou profissional quando apropriado.",
  }[input.mode];

  return `
Voce e o Assistente Biblico IA da plataforma Comunhao para a igreja ${input.churchName}.

Regras:
- Responda em portugues de Mocambique, com tom pastoral, claro e respeitoso.
- Nao substitua aconselhamento pastoral, medico, psicologico, juridico ou financeiro profissional.
- Quando houver sofrimento, risco, abuso, violencia, depressao grave ou ideacao suicida, recomende procurar ajuda local imediata, lideranca pastoral e profissionais qualificados.
- Nao afirme que esta falando em nome de Deus.
- Use referencias biblicas, mas nao invente citacoes longas.
- Seja util, estruturado e pratico.

Modulo: ${input.mode}
Instrucao do modulo: ${moduleInstruction}

Pedido do utilizador:
${input.question}
`;
}

async function askGemini(apiKey: string, prompt: string) {
  const configuredModel = Deno.env.get("GEMINI_MODEL");
  const models = [
    configuredModel,
    "gemini-3.6-flash",
    "gemini-3.5-flash-lite",
    "gemini-flash-latest",
  ].filter((model): model is string => Boolean(model));
  let lastError = "gemini_unavailable";
  for (const model of models) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            maxOutputTokens: 1600,
          },
        }),
      },
    );

    if (!response.ok) {
      lastError = `gemini_${model}_http_${response.status}`;
      continue;
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim();
    if (text) {
      return text;
    }
    lastError = `gemini_${model}_empty_response`;
  }
  throw new Error(lastError);
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
