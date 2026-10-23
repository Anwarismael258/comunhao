class DailyWordEntry {
  const DailyWordEntry({
    required this.id,
    required this.reference,
    required this.verse,
    required this.devotional,
    required this.readingPlan,
  });

  final String id;
  final String reference;
  final String verse;
  final String devotional;
  final String readingPlan;
}

const dailyWordCatalog = <DailyWordEntry>[
  DailyWordEntry(
    id: 'dw-1',
    reference: 'Salmos 121:1-2',
    verse: 'Elevo os meus olhos para os montes: de onde me vira o socorro?',
    devotional:
        'Mesmo em dias pesados, a igreja caminha lembrando que o socorro vem do Senhor e nao apenas das nossas forcas.',
    readingPlan: 'Leitura de hoje: Salmos 121, Romanos 8 e Joao 15.',
  ),
  DailyWordEntry(
    id: 'dw-2',
    reference: 'Isaias 40:31',
    verse:
        'Mas os que esperam no Senhor renovarao as suas forcas e subirao com asas como aguias.',
    devotional:
        'Esperar em Deus nao e ficar parado. E continuar fiel enquanto Ele fortalece o coracao.',
    readingPlan: 'Leitura de hoje: Isaias 40, Tiago 1 e Salmos 27.',
  ),
  DailyWordEntry(
    id: 'dw-3',
    reference: 'Mateus 5:14',
    verse: 'Vos sois a luz do mundo.',
    devotional:
        'A comunidade de fe brilha quando cada membro decide servir, encorajar e permanecer acessivel.',
    readingPlan: 'Leitura de hoje: Mateus 5, Filipenses 2 e Proverbios 3.',
  ),
  DailyWordEntry(
    id: 'dw-4',
    reference: 'Josue 1:9',
    verse:
        'Se forte e corajoso. Nao temas, nem te espantes, porque o Senhor teu Deus e contigo.',
    devotional:
        'Coragem espiritual nao e ausencia de medo. E obediencia sustentada pela presenca de Deus.',
    readingPlan: 'Leitura de hoje: Josue 1, Efesios 6 e Salmos 46.',
  ),
  DailyWordEntry(
    id: 'dw-5',
    reference: 'Romanos 12:12',
    verse:
        'Alegrai-vos na esperanca, sede pacientes na tribulacao, perseverai na oracao.',
    devotional:
        'A vida da igreja cresce quando a esperanca, a paciencia e a oracao caminham juntas.',
    readingPlan: 'Leitura de hoje: Romanos 12, Salmos 34 e Colossenses 3.',
  ),
  DailyWordEntry(
    id: 'dw-6',
    reference: 'Hebreus 10:24-25',
    verse:
        'Consideremo-nos tambem uns aos outros, para nos estimularmos ao amor e as boas obras.',
    devotional:
        'Comunhao verdadeira nao isola. Aproxima, fortalece e reacende pessoas para a missao.',
    readingPlan: 'Leitura de hoje: Hebreus 10, Atos 2 e Salmos 133.',
  ),
  DailyWordEntry(
    id: 'dw-7',
    reference: 'Filipenses 4:6',
    verse:
        'Nao andeis ansiosos por coisa alguma, mas em tudo sejam conhecidos diante de Deus os vossos pedidos.',
    devotional:
        'A oracao continua a ser o lugar mais seguro para transformar ansiedade em dependencia de Deus.',
    readingPlan: 'Leitura de hoje: Filipenses 4, Salmos 91 e Mateus 6.',
  ),
];
