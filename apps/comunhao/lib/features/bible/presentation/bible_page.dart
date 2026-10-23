import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({
    required this.church,
    required this.member,
    this.initialTabIndex = 0,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final int initialTabIndex;

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  Set<String> _favorites = const {};
  Set<String> _highlights = const {};
  Map<String, String> _highlightColors = const {};
  Map<String, String> _notes = const {};
  List<String> _history = const [];
  List<_ReadingPlan> _customPlans = const [];
  List<String> _readingDays = const [];
  List<String> _prayerDays = const [];
  List<String> _studyCompletions = const [];
  List<String> _answeredPrayers = const [];
  List<String> _spiritualGoals = const [];
  List<_SermonNote> _sermonNotes = const [];
  final List<_BibleChatMessage> _chat = [];
  List<_BibleBook> _apiBooks = const [];
  List<_BibleChapter> _apiChapters = const [];
  List<_BibleVerse> _apiSearchResults = const [];
  _BibleVerse? _apiSelectedVerse;
  String? _selectedBookId;
  String? _selectedChapterId;
  String? _bibleLabel;
  String _assistantMode = 'explain';
  String _searchMode = 'Palavra';
  String _translation = 'ARC';
  String _selectedTheme = 'Ansiedade';
  String _quizCategory = 'Evangelhos';
  String _quizLevel = 'Facil';
  int _quizIndex = 0;
  int _quizScore = 0;
  String? _quizAnswer;
  String _selectedReference = _sampleVerses.first.reference;
  bool _busyAi = false;
  bool _loadingBible = false;
  bool _searchingBible = false;
  bool _readerDarkMode = false;
  bool _offlineMode = true;
  bool _continuousScroll = true;
  double _fontSize = 20;
  double _audioSpeed = 1;

  List<_ReadingPlan> get _allReadingPlans => [
        ..._readingPlans,
        ..._customPlans,
      ];

  _BibleVerse get _selectedVerse =>
      _apiSelectedVerse ??
      _sampleVerses.firstWhere(
        (verse) => verse.reference == _selectedReference,
        orElse: () => _sampleVerses.first,
      );

  List<_BibleVerse> get _searchResults {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _sampleVerses;
    }
    return _sampleVerses.where((verse) {
      return verse.reference.toLowerCase().contains(query) ||
          verse.text.toLowerCase().contains(query) ||
          verse.theme.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadState();
    _loadBibleBooks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites =
          (preferences.getStringList(_key('favorites')) ?? const <String>[])
              .toSet();
      _highlights =
          (preferences.getStringList(_key('highlights')) ?? const <String>[])
              .toSet();
      _highlightColors = Map<String, String>.from(
        jsonDecode(preferences.getString(_key('highlight_colors')) ?? '{}')
            as Map,
      );
      _history = preferences.getStringList(_key('history')) ?? const <String>[];
      _customPlans = _decodePlans(preferences.getString(_key('plans')));
      _readingDays =
          preferences.getStringList(_key('reading_days')) ?? const <String>[];
      _prayerDays =
          preferences.getStringList(_key('prayer_days')) ?? const <String>[];
      _studyCompletions =
          preferences.getStringList(_key('studies_done')) ?? const <String>[];
      _answeredPrayers = preferences.getStringList(_key('answered_prayers')) ??
          const <String>[];
      _spiritualGoals = preferences.getStringList(_key('spiritual_goals')) ??
          const <String>[];
      _sermonNotes = _decodeSermonNotes(preferences.getString(_key('sermons')));
      _notes = Map<String, String>.from(
        jsonDecode(preferences.getString(_key('notes')) ?? '{}') as Map,
      );
      _translation = preferences.getString(_key('translation')) ?? 'ARC';
      _readerDarkMode = preferences.getBool(_key('reader_dark')) ?? false;
      _offlineMode = preferences.getBool(_key('offline_mode')) ?? true;
      _continuousScroll =
          preferences.getBool(_key('continuous_scroll')) ?? true;
      _fontSize = preferences.getDouble(_key('font_size')) ?? 20;
      _audioSpeed = preferences.getDouble(_key('audio_speed')) ?? 1;
      _noteController.text = _notes[_selectedReference] ?? '';
    });
    await _loadRemoteState();
  }

  Future<void> _loadRemoteState() async {
    try {
      final response = await Supabase.instance.client
          .from('member_bible_state')
          .select('state')
          .eq('member_id', widget.member.id)
          .maybeSingle();
      final state = response?['state'];
      if (!mounted || state is! Map) return;
      final remote = Map<String, dynamic>.from(state);
      setState(() {
        _favorites = _stringSet(remote['favorites'], _favorites);
        _highlights = _stringSet(remote['highlights'], _highlights);
        _history = _stringList(remote['history'], _history);
        _readingDays = _stringList(remote['reading_days'], _readingDays);
        _prayerDays = _stringList(remote['prayer_days'], _prayerDays);
        _studyCompletions =
            _stringList(remote['study_completions'], _studyCompletions);
        _answeredPrayers =
            _stringList(remote['answered_prayers'], _answeredPrayers);
        _spiritualGoals =
            _stringList(remote['spiritual_goals'], _spiritualGoals);
        _notes = _stringMap(remote['notes'], _notes);
        _highlightColors =
            _stringMap(remote['highlight_colors'], _highlightColors);
      });
    } catch (_) {}
  }

  Set<String> _stringSet(dynamic value, Set<String> fallback) =>
      value is List ? value.map((item) => item.toString()).toSet() : fallback;

  List<String> _stringList(dynamic value, List<String> fallback) =>
      value is List ? value.map((item) => item.toString()).toList() : fallback;

  Map<String, String> _stringMap(dynamic value, Map<String, String> fallback) =>
      value is Map
          ? value.map((key, item) => MapEntry(key.toString(), item.toString()))
          : fallback;

  Future<void> _saveState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key('favorites'), _favorites.toList());
    await preferences.setStringList(_key('highlights'), _highlights.toList());
    await preferences.setString(
      _key('highlight_colors'),
      jsonEncode(_highlightColors),
    );
    await preferences.setStringList(
        _key('history'), _history.take(40).toList());
    await preferences.setStringList(_key('reading_days'), _readingDays);
    await preferences.setString(_key('notes'), jsonEncode(_notes));
    await preferences.setString(
      _key('plans'),
      jsonEncode(_customPlans.map((plan) => plan.toMap()).toList()),
    );
    await preferences.setStringList(_key('prayer_days'), _prayerDays);
    await preferences.setStringList(_key('studies_done'), _studyCompletions);
    await preferences.setStringList(_key('answered_prayers'), _answeredPrayers);
    await preferences.setStringList(_key('spiritual_goals'), _spiritualGoals);
    await preferences.setString(
      _key('sermons'),
      jsonEncode(_sermonNotes.map((note) => note.toMap()).toList()),
    );
    await preferences.setString(_key('translation'), _translation);
    await preferences.setBool(_key('reader_dark'), _readerDarkMode);
    await preferences.setBool(_key('offline_mode'), _offlineMode);
    await preferences.setBool(_key('continuous_scroll'), _continuousScroll);
    await preferences.setDouble(_key('font_size'), _fontSize);
    await preferences.setDouble(_key('audio_speed'), _audioSpeed);
    try {
      await Supabase.instance.client.from('member_bible_state').upsert({
        'member_id': widget.member.id,
        'church_id': widget.church.id,
        'state': {
          'favorites': _favorites.toList(),
          'highlights': _highlights.toList(),
          'history': _history,
          'reading_days': _readingDays,
          'prayer_days': _prayerDays,
          'study_completions': _studyCompletions,
          'answered_prayers': _answeredPrayers,
          'spiritual_goals': _spiritualGoals,
          'notes': _notes,
          'highlight_colors': _highlightColors,
          'plans': _allReadingPlans.map((plan) => plan.toMap()).toList(),
        },
      });
    } catch (_) {}
  }

  String _key(String suffix) => 'bible_${widget.member.id}_$suffix';

  void _selectVerse(_BibleVerse verse) {
    setState(() {
      _selectedReference = verse.reference;
      _apiSelectedVerse =
          verse.theme == 'API.Bible' ? verse : _apiSelectedVerse;
      _noteController.text = _notes[verse.reference] ?? '';
      _history = [
        verse.reference,
        ..._history.where((item) => item != verse.reference),
      ];
    });
    _saveState();
  }

  void _selectVerseAndOpenActions(_BibleVerse verse) {
    _selectVerse(verse);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openVerseActions(verse);
    });
  }

  void _openReference(String reference) {
    final local = _sampleVerses.where((verse) => verse.reference == reference);
    if (local.isNotEmpty) {
      _selectVerse(local.first);
      return;
    }
    setState(() {
      _selectedReference = reference;
      _searchController.text = reference;
      _history = [
        reference,
        ..._history.where((item) => item != reference),
      ];
    });
    _saveState();
    _searchApiBible();
  }

  void _scheduleBibleSearch() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _apiSearchResults = const []);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 650),
      () {
        if (mounted) _searchApiBible();
      },
    );
  }

  Future<void> _loadBibleBooks() async {
    setState(() => _loadingBible = true);
    try {
      final data = await _invokeBibleApi({'action': 'books'});
      final books = (data['books'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _BibleBook.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      final bible = data['bible'] as Map?;
      if (!mounted) return;
      setState(() {
        _apiBooks = books;
        _bibleLabel = bible == null
            ? null
            : '${bible['name'] ?? 'Biblia'} (${bible['abbreviation'] ?? ''})';
        if (books.isNotEmpty) {
          _selectedBookId ??= books.first.id;
        }
      });
      if (books.isNotEmpty) {
        await _loadChapters(books.first.id);
      }
    } finally {
      if (mounted) setState(() => _loadingBible = false);
    }
  }

  Future<void> _loadChapters(String bookId) async {
    setState(() {
      _loadingBible = true;
      _selectedBookId = bookId;
      _apiChapters = const [];
      _selectedChapterId = null;
    });
    try {
      final data = await _invokeBibleApi({
        'action': 'chapters',
        'book_id': bookId,
      });
      final chapters = (data['chapters'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _BibleChapter.fromMap(Map<String, dynamic>.from(item)))
          .where((chapter) => chapter.id.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _apiChapters = chapters;
        if (chapters.isNotEmpty) {
          _selectedChapterId = chapters.first.id;
        }
      });
      if (chapters.isNotEmpty) {
        await _loadPassage(chapters.first.id);
      }
    } finally {
      if (mounted) setState(() => _loadingBible = false);
    }
  }

  Future<void> _loadPassage(String passageId) async {
    setState(() {
      _loadingBible = true;
      _selectedChapterId = passageId;
    });
    try {
      final data = await _invokeBibleApi({
        'action': 'passage',
        'passage_id': passageId,
      });
      final passage = data['passage'] as Map?;
      if (passage == null) return;
      final verse = _BibleVerse(
        reference: (passage['reference'] as String?) ?? passageId,
        text: (passage['text'] as String?) ?? '',
        theme: 'API.Bible',
      );
      if (!mounted) return;
      setState(() {
        _apiSelectedVerse = verse;
        _selectedReference = verse.reference;
        _history = [
          verse.reference,
          ..._history.where((item) => item != verse.reference),
        ];
        _noteController.text = _notes[verse.reference] ?? '';
      });
      _saveState();
    } finally {
      if (mounted) setState(() => _loadingBible = false);
    }
  }

  Future<void> _searchApiBible() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    setState(() => _searchingBible = true);
    try {
      final data = await _invokeBibleApi({
        'action': 'search',
        'query': query,
      });
      final results = (data['results'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            return _BibleVerse(
              reference: (map['reference'] as String?) ?? '',
              text: (map['text'] as String?) ?? '',
              theme: 'API.Bible',
            );
          })
          .where((verse) => verse.reference.isNotEmpty && verse.text.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _apiSearchResults = results;
        if (results.length == 1) {
          _selectedReference = results.first.reference;
          _apiSelectedVerse = results.first;
          _noteController.text = _notes[results.first.reference] ?? '';
          _history = [
            results.first.reference,
            ..._history.where((item) => item != results.first.reference),
          ];
        }
      });
      if (results.length == 1) {
        _saveState();
      }
    } finally {
      if (mounted) setState(() => _searchingBible = false);
    }
  }

  Future<void> _openDirectReference(String reference) async {
    final query = reference.trim();
    if (query.isEmpty) return;
    setState(() => _loadingBible = true);
    try {
      final data = await _invokeBibleApi({'action': 'search', 'query': query});
      final results = (data['results'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (results.isEmpty) {
        _message('Referência não encontrada. Exemplo: João 3:16');
        return;
      }
      final result = results.first;
      final passageId = result['id']?.toString();
      if (passageId == null || passageId.isEmpty) {
        _message('Não foi possível abrir essa referência.');
        return;
      }
      await _loadPassage(passageId);
    } finally {
      if (mounted) setState(() => _loadingBible = false);
    }
  }

  Future<void> _createReadingPlan() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final references = TextEditingController();
    final created = await showDialog<_ReadingPlan>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo plano de leitura'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                ),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                TextField(
                  controller: references,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Referencias',
                    hintText: 'Ex.: Joao 3:16, Salmos 37:5, Romanos 8:28',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final days = references.text
                  .split(RegExp(r'[,;\n]'))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false);
              if (title.text.trim().length < 3 || days.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                _ReadingPlan(
                  title: title.text.trim(),
                  description: description.text.trim().isEmpty
                      ? 'Plano criado por ti.'
                      : description.text.trim(),
                  days: days,
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Criar plano'),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    references.dispose();
    if (created == null) return;
    setState(() => _customPlans = [..._customPlans, created]);
    await _saveState();
    _message('Plano criado.');
  }

  Future<void> _addSpiritualGoal() async {
    final controller = TextEditingController();
    final goal = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova meta espiritual'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Meta',
            hintText: 'Ex.: Orar 10 minutos por dia',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (goal == null || goal.length < 3) return;
    setState(() => _spiritualGoals = [goal, ..._spiritualGoals]);
    await _saveState();
  }

  Future<void> _addAnsweredPrayer() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oracao respondida'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resumo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.length < 3) return;
    setState(() => _answeredPrayers = [value, ..._answeredPrayers]);
    await _saveState();
  }

  Future<void> _addSermonNote() async {
    final title = TextEditingController();
    final preacher = TextEditingController();
    final theme = TextEditingController();
    final references = TextEditingController();
    final notes = TextEditingController();
    final created = await showDialog<_SermonNote>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova anotacao de sermao'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                ),
                TextField(
                  controller: preacher,
                  decoration: const InputDecoration(labelText: 'Pregador'),
                ),
                TextField(
                  controller: theme,
                  decoration: const InputDecoration(labelText: 'Tema'),
                ),
                TextField(
                  controller: references,
                  decoration:
                      const InputDecoration(labelText: 'Versiculos usados'),
                ),
                TextField(
                  controller: notes,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Anotacoes'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (title.text.trim().length < 3) return;
              Navigator.of(context).pop(
                _SermonNote(
                  title: title.text.trim(),
                  preacher: preacher.text.trim().isEmpty
                      ? 'Nao informado'
                      : preacher.text.trim(),
                  date: DateTime.now(),
                  church: widget.church.name,
                  theme: theme.text.trim(),
                  references: references.text.trim(),
                  notes: notes.text.trim(),
                  favorite: false,
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
    title.dispose();
    preacher.dispose();
    theme.dispose();
    references.dispose();
    notes.dispose();
    if (created == null) return;
    setState(() => _sermonNotes = [created, ..._sermonNotes]);
    await _saveState();
    _message('Anotacao guardada.');
  }

  Future<void> _copySermonNote(_SermonNote note) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${note.title}\nPregador: ${note.preacher}\nTema: ${note.theme}\nVersiculos: ${note.references}\n\n${note.notes}',
      ),
    );
    _message('Anotacao copiada para exportar/partilhar.');
  }

  void _markToday(String type) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    setState(() {
      if (type == 'prayer') {
        _prayerDays = [today, ..._prayerDays.where((day) => day != today)];
      } else {
        _readingDays = [today, ..._readingDays.where((day) => day != today)];
      }
    });
    _saveState();
  }

  void _answerQuiz(String answer) {
    if (_quizAnswer != null) return;
    final question =
        _visibleQuizQuestions[_quizIndex % _visibleQuizQuestions.length];
    setState(() {
      _quizAnswer = answer;
      if (answer == question.correctAnswer) {
        _quizScore += 1;
      }
    });
  }

  void _nextQuiz() {
    setState(() {
      _quizIndex = (_quizIndex + 1) % _visibleQuizQuestions.length;
      _quizAnswer = null;
    });
  }

  List<_QuizQuestion> get _visibleQuizQuestions {
    final filtered = _quizQuestions
        .where(
          (item) => item.category == _quizCategory && item.level == _quizLevel,
        )
        .toList(growable: false);
    return filtered.isEmpty ? _quizQuestions : filtered;
  }

  Future<Map<String, dynamic>> _invokeBibleApi(
      Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'comunhao-bible-api',
      body: body,
    );
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  void _toggleFavorite() {
    setState(() {
      final next = Set<String>.from(_favorites);
      if (next.contains(_selectedReference)) {
        next.remove(_selectedReference);
      } else {
        next.add(_selectedReference);
      }
      _favorites = next;
    });
    _saveState();
  }

  void _toggleHighlight() {
    setState(() {
      final next = Set<String>.from(_highlights);
      if (next.contains(_selectedReference)) {
        next.remove(_selectedReference);
      } else {
        next.add(_selectedReference);
      }
      _highlights = next;
    });
    _saveState();
  }

  Future<void> _setHighlightColor(String reference, String colorLabel) async {
    setState(() {
      _highlights = {..._highlights, reference};
      _highlightColors = {
        ..._highlightColors,
        reference: colorLabel,
      };
    });
    await _saveState();
    _message('Destaque guardado em $colorLabel.');
  }

  Future<void> _copyVerse(_BibleVerse verse) async {
    await Clipboard.setData(
      ClipboardData(text: '${verse.reference}\n${verse.text}'),
    );
    _message('Versiculo copiado.');
  }

  Future<void> _openNoteDialog(_BibleVerse verse) async {
    final controller = TextEditingController(text: _notes[verse.reference]);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nota em ${verse.reference}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Anotacao pessoal',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null) return;
    setState(() {
      final next = Map<String, String>.from(_notes);
      if (saved.isEmpty) {
        next.remove(verse.reference);
      } else {
        next[verse.reference] = saved;
      }
      _notes = next;
      if (_selectedReference == verse.reference) {
        _noteController.text = saved;
      }
    });
    await _saveState();
    _message('Nota guardada.');
  }

  void _openAudioSheet(_BibleVerse verse) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biblia em audio',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${verse.reference} - $_translation'),
            const SizedBox(height: 12),
            SelectableText(verse.text),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Play',
                  onPressed: () => _message(
                    'Audio preparado. Ligue ficheiros de audio quando estiverem disponiveis.',
                  ),
                  icon: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Pausa',
                  onPressed: () => _message('Audio pausado.'),
                  icon: const Icon(Icons.pause),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    min: 0.75,
                    max: 2,
                    divisions: 5,
                    label: '${_audioSpeed.toStringAsFixed(2)}x',
                    value: _audioSpeed,
                    onChanged: (value) {
                      setState(() => _audioSpeed = value);
                      _saveState();
                    },
                  ),
                ),
                Text('${_audioSpeed.toStringAsFixed(2)}x'),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _message('Download offline marcado.'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download'),
            ),
          ],
        ),
      ),
    );
  }

  void _studyVerse(_BibleVerse verse) {
    setState(() {
      _assistantMode = 'study';
    });
    _askAssistant(
      'Faca um estudo biblico pratico sobre ${verse.reference}: ${verse.text}',
    );
    _message('Estudo enviado ao Assistente Biblico.');
  }

  void _explainVerse(_BibleVerse verse) {
    setState(() {
      _assistantMode = 'explain';
    });
    _askAssistant('Explique ${verse.reference}: ${verse.text}');
    _message('Explicacao enviada ao Assistente Biblico.');
  }

  void _openVerseActions(_BibleVerse verse) {
    final favorite = _favorites.contains(verse.reference);
    final highlighted = _highlights.contains(verse.reference);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          children: [
            ListTile(
              title: Text(verse.reference),
              subtitle: Text(
                verse.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VerseActionChip(
                  icon: Icons.copy_outlined,
                  label: 'Copiar',
                  onTap: () {
                    Navigator.of(context).pop();
                    _copyVerse(verse);
                  },
                ),
                _VerseActionChip(
                  icon: Icons.ios_share_outlined,
                  label: 'Partilhar',
                  onTap: () {
                    Navigator.of(context).pop();
                    _shareVerse();
                  },
                ),
                _VerseActionChip(
                  icon: Icons.school_outlined,
                  label: 'Estudar',
                  onTap: () {
                    Navigator.of(context).pop();
                    _studyVerse(verse);
                  },
                ),
                _VerseActionChip(
                  icon: favorite ? Icons.favorite : Icons.favorite_border,
                  label: favorite ? 'Favorito' : 'Favoritos',
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleFavorite();
                  },
                ),
                _VerseActionChip(
                  icon: highlighted
                      ? Icons.border_color
                      : Icons.border_color_outlined,
                  label: 'Destacar',
                  onTap: () => _openHighlightPicker(verse),
                ),
                _VerseActionChip(
                  icon: Icons.note_alt_outlined,
                  label: 'Nota',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openNoteDialog(verse);
                  },
                ),
                _VerseActionChip(
                  icon: Icons.volume_up_outlined,
                  label: 'Ouvir',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openAudioSheet(verse);
                  },
                ),
                _VerseActionChip(
                  icon: Icons.smart_toy_outlined,
                  label: 'Explicar IA',
                  onTap: () {
                    Navigator.of(context).pop();
                    _explainVerse(verse);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openHighlightPicker(_BibleVerse verse) {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _highlightOptions.entries.map((entry) {
            return ActionChip(
              avatar: CircleAvatar(backgroundColor: entry.value),
              label: Text(entry.key),
              onPressed: () {
                Navigator.of(context).pop();
                _setHighlightColor(verse.reference, entry.key);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _saveNote() {
    setState(() {
      final next = Map<String, String>.from(_notes);
      final value = _noteController.text.trim();
      if (value.isEmpty) {
        next.remove(_selectedReference);
      } else {
        next[_selectedReference] = value;
      }
      _notes = next;
    });
    _saveState();
    _message('Nota guardada.');
  }

  Future<void> _shareVerse() async {
    final verse = _selectedVerse;
    await Clipboard.setData(
      ClipboardData(text: '${verse.reference}\n${verse.text}'),
    );
    _message('Versiculo copiado para partilhar.');
  }

  Future<void> _askAssistant([String? preset]) async {
    final question = (preset ?? _chatController.text).trim();
    if (question.length < 3 || _busyAi) return;
    setState(() {
      _busyAi = true;
      _chat.add(_BibleChatMessage.user(question));
      _chatController.clear();
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'bible-ai-assistant',
        body: {
          'mode': _assistantMode,
          'question': question,
          'church_name': widget.church.name,
        },
      );
      final data = response.data;
      final answer = data is Map
          ? (data['answer']?.toString() ?? 'Sem resposta agora.')
          : 'Sem resposta agora.';
      if (!mounted) return;
      setState(() => _chat.add(_BibleChatMessage.assistant(answer)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _chat.add(
            _BibleChatMessage.assistant(
              'Nao foi possivel chamar a IA agora. Verifica a ligacao e a configuracao da Edge Function.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAi = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verse = _selectedVerse;
    return DefaultTabController(
      length: 13,
      initialIndex: widget.initialTabIndex.clamp(0, 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF4), Color(0xFFF7F4EF)],
          ),
        ),
        child: Column(
          children: [
            _BibleTopHeader(
              churchName: widget.church.name,
              reference: verse.reference,
              text: verse.text,
              bibleLabel: _bibleLabel,
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.88),
              elevation: 0,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                tabs: [
                  Tab(icon: Icon(Icons.home_outlined), text: 'Inicio'),
                  Tab(icon: Icon(Icons.menu_book_outlined), text: 'Ler'),
                  Tab(icon: Icon(Icons.sell_outlined), text: 'Estudos'),
                  Tab(icon: Icon(Icons.search), text: 'Pesquisa'),
                  Tab(
                      icon: Icon(Icons.calendar_month_outlined),
                      text: 'Planos'),
                  Tab(icon: Icon(Icons.quiz_outlined), text: 'Quiz'),
                  Tab(icon: Icon(Icons.edit_note_outlined), text: 'Sermoes'),
                  Tab(icon: Icon(Icons.favorite_border), text: 'Favoritos'),
                  Tab(icon: Icon(Icons.note_alt_outlined), text: 'Notas'),
                  Tab(
                      icon: Icon(Icons.border_color_outlined),
                      text: 'Destaques'),
                  Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Devocionais'),
                  Tab(
                      icon: Icon(Icons.smart_toy_outlined),
                      text: 'Assistente IA'),
                  Tab(icon: Icon(Icons.history), text: 'Historico'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildJourneyTab(),
                  _buildBibleTab(),
                  _buildThemesTab(),
                  _buildSearchTab(),
                  _buildPlansTab(),
                  _buildQuizTab(),
                  _buildSermonNotesTab(),
                  _buildReferenceList(_favorites, 'Sem favoritos ainda.'),
                  _buildNotesTab(),
                  _buildReferenceList(_highlights, 'Sem destaques ainda.'),
                  _buildDevotionalsTab(),
                  _buildAssistantTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyTab() {
    final completedPlans = _allReadingPlans
        .where((plan) => plan.days.every(_history.contains))
        .length;
    final readStreak = _streakCount(_readingDays);
    final prayerStreak = _streakCount(_prayerDays);
    final totalHabits = readStreak + prayerStreak + completedPlans;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        _buildBibleHomeSection(),
        const SizedBox(height: 16),
        _JourneyHeroCard(
          readStreak: readStreak,
          prayerStreak: prayerStreak,
          completedPlans: completedPlans,
          answeredPrayers: _answeredPrayers.length,
          score: totalHabits,
          onMarkReading: () => _markToday('reading'),
          onMarkPrayer: () => _markToday('prayer'),
          onAddGoal: _addSpiritualGoal,
          onAnsweredPrayer: _addAnsweredPrayer,
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Ritmo da semana',
          subtitle: 'Pequenos passos constantes para fortalecer a caminhada.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _JourneyMetric(
                    icon: Icons.menu_book_outlined,
                    label: 'Leitura',
                    value: '$readStreak dias',
                    color: const Color(0xFF7C2D12),
                  ),
                  _JourneyMetric(
                    icon: Icons.volunteer_activism_outlined,
                    label: 'Oracao',
                    value: '$prayerStreak dias',
                    color: const Color(0xFF6D28D9),
                  ),
                  _JourneyMetric(
                    icon: Icons.task_alt,
                    label: 'Planos',
                    value: '$completedPlans concluidos',
                    color: const Color(0xFF047857),
                  ),
                  _JourneyMetric(
                    icon: Icons.favorite_outline,
                    label: 'Respondidas',
                    value: '${_answeredPrayers.length}',
                    color: const Color(0xFFBE123C),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Metas pessoais',
          subtitle: 'Objetivos espirituais definidos por ti.',
          child: _spiritualGoals.isEmpty
              ? const _EmptyState(
                  icon: Icons.flag_outlined,
                  title: 'Sem metas ainda',
                  message: 'Cria uma meta simples para esta semana.',
                )
              : Column(
                  children: _spiritualGoals
                      .map(
                        (goal) => _SoftListTile(
                          icon: Icons.flag_outlined,
                          title: goal,
                          subtitle: 'Toque para concluir/remover',
                          onTap: () {
                            setState(() {
                              _spiritualGoals = _spiritualGoals
                                  .where((item) => item != goal)
                                  .toList(growable: false);
                            });
                            _saveState();
                          },
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Orações respondidas',
          subtitle: 'Um memorial pessoal de gratidão.',
          child: _answeredPrayers.isEmpty
              ? const _EmptyState(
                  icon: Icons.favorite_outline,
                  title: 'Sem registos ainda',
                  message: 'Quando uma oração for respondida, guarda aqui.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _answeredPrayers
                      .map(
                        (item) => _SoftListTile(
                          icon: Icons.favorite_outline,
                          title: item,
                          subtitle: 'Gratidão registada',
                          onTap: () {},
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildBibleHomeSection() {
    final verseOfDay = _sampleVerses[DateTime.now().day % _sampleVerses.length];
    final lastReference =
        _history.isEmpty ? verseOfDay.reference : _history.first;
    final activePlan = _allReadingPlans.isEmpty ? null : _allReadingPlans.first;
    final devotional = _devotionals[DateTime.now().day % _devotionals.length];
    return _Section(
      title: 'Inicio biblico',
      subtitle: 'Leitura, plano, devocional e pesquisa rapida num so lugar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SoftListTile(
            icon: Icons.wb_sunny_outlined,
            title: 'Versiculo do dia: ${verseOfDay.reference}',
            subtitle: verseOfDay.text,
            onTap: () => _selectVerseAndOpenActions(verseOfDay),
          ),
          _SoftListTile(
            icon: Icons.bookmark_outline,
            title: 'Continuar leitura',
            subtitle: lastReference,
            onTap: () => _openReference(lastReference),
          ),
          _SoftListTile(
            icon: Icons.calendar_month_outlined,
            title: activePlan == null
                ? 'Plano de leitura'
                : 'Plano em andamento: ${activePlan.title}',
            subtitle: activePlan == null
                ? 'Escolhe um plano para acompanhar o progresso.'
                : '${activePlan.days.where(_history.contains).length}/${activePlan.days.length} leituras concluidas',
            onTap: () {
              if (activePlan != null && activePlan.days.isNotEmpty) {
                _openReference(activePlan.days.first);
              }
            },
          ),
          _SoftListTile(
            icon: Icons.local_florist_outlined,
            title: 'Devocional do dia: ${devotional.title}',
            subtitle: devotional.reference,
            onTap: () => _openReference(devotional.reference),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Pesquisa rapida',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              _searchController.text = value;
              _scheduleBibleSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBibleTab() {
    final verse = _selectedVerse;
    final favorite = _favorites.contains(_selectedReference);
    final highlighted = _highlights.contains(_selectedReference);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        _ScriptureReaderCard(
          verse: verse,
          bibleLabel: _bibleLabel,
          loading: _loadingBible,
          favorite: favorite,
          highlighted: highlighted,
          books: _apiBooks,
          chapters: _apiChapters,
          selectedBookId: _selectedBookId,
          selectedChapterId: _selectedChapterId,
          selectedReference: _selectedReference,
          translation: _translation,
          readerDarkMode: _readerDarkMode,
          offlineMode: _offlineMode,
          continuousScroll: _continuousScroll,
          fontSize: _fontSize,
          onBookChanged: (value) {
            if (value != null) _loadChapters(value);
          },
          onChapterChanged: (value) {
            if (value != null) _loadPassage(value);
          },
          onReferenceSubmitted: _openDirectReference,
          onLocalReferenceChanged: (value) {
            final selected = _sampleVerses.firstWhere(
              (item) => item.reference == value,
              orElse: () => _sampleVerses.first,
            );
            _selectVerse(selected);
          },
          onFavorite: _toggleFavorite,
          onHighlight: _toggleHighlight,
          onShare: _shareVerse,
          onVerseTap: () => _openVerseActions(verse),
          onTranslationChanged: (value) {
            if (value == null) return;
            setState(() => _translation = value);
            _saveState();
          },
          onReaderDarkChanged: (value) {
            setState(() => _readerDarkMode = value);
            _saveState();
          },
          onOfflineChanged: (value) {
            setState(() => _offlineMode = value);
            _saveState();
          },
          onContinuousScrollChanged: (value) {
            setState(() => _continuousScroll = value);
            _saveState();
          },
          onFontSizeChanged: (value) {
            setState(() => _fontSize = value);
            _saveState();
          },
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Nota pessoal',
          subtitle: 'Guarda observações deste texto neste dispositivo.',
          child: Column(
            children: [
              TextField(
                controller: _noteController,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Escreve uma reflexão, pergunta ou aplicação',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saveNote,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar nota'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemesTab() {
    final verses = _themeVerses[_selectedTheme] ?? const <_ThemeVerse>[];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _themeVerses.keys.map((theme) {
            return ChoiceChip(
              label: Text(theme),
              selected: _selectedTheme == theme,
              onSelected: (_) => setState(() => _selectedTheme = theme),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _Section(
          title: _selectedTheme,
          subtitle: 'Versiculos relacionados, com explicacao breve.',
          child: Column(
            children: verses.map((item) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(item.reference),
                  subtitle: Text('${item.text}\n\n${item.explanation}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Copiar',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              '${item.reference}\n${item.text}\n${item.explanation}',
                        ),
                      );
                      _message('Versiculo copiado.');
                    },
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                  onTap: () {
                    _selectVerse(
                      _BibleVerse(
                        reference: item.reference,
                        text: item.text,
                        theme: _selectedTheme,
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    final questions = _visibleQuizQuestions;
    final question = questions[_quizIndex % questions.length];
    final answered = _quizAnswer != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Section(
          title: 'Quiz Biblico',
          subtitle: 'Aprendizagem por categorias e niveis.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DropdownButton<String>(
                    value: _quizCategory,
                    items: _quizCategories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _quizCategory = value;
                        _quizIndex = 0;
                        _quizScore = 0;
                        _quizAnswer = null;
                      });
                    },
                  ),
                  DropdownButton<String>(
                    value: _quizLevel,
                    items: _quizLevels
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _quizLevel = value;
                        _quizIndex = 0;
                        _quizScore = 0;
                        _quizAnswer = null;
                      });
                    },
                  ),
                  Chip(label: Text('${questions.length} perguntas')),
                  Chip(label: Text('Acertos: $_quizScore')),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_quizIndex + (answered ? 1 : 0)) / questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              Text(
                'Pergunta ${(_quizIndex % questions.length) + 1} de ${questions.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    question.question,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...question.options.map((option) {
                final correct = option == question.correctAnswer;
                final selected = option == _quizAnswer;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: answered && correct
                            ? Colors.green
                            : answered && selected
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).dividerColor,
                      ),
                    ),
                    title: Text(option),
                    leading: Icon(
                      answered && correct
                          ? Icons.check_circle
                          : answered && selected
                              ? Icons.cancel_outlined
                              : Icons.radio_button_unchecked,
                    ),
                    onTap: answered ? null : () => _answerQuiz(option),
                  ),
                );
              }),
              if (answered) ...[
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _quizAnswer == question.correctAnswer
                              ? 'Resposta correta'
                              : 'Resposta correta: ${question.correctAnswer}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(question.explanation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _nextQuiz,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Proxima pergunta'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSermonNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _addSermonNote,
            icon: const Icon(Icons.add),
            label: const Text('Nova anotacao'),
          ),
        ),
        const SizedBox(height: 16),
        if (_sermonNotes.isEmpty)
          const Text('Sem anotacoes de sermoes ainda.')
        else
          ..._sermonNotes.map((note) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Section(
                title: note.title,
                subtitle:
                    '${note.preacher} - ${note.church} - ${_formatDate(note.date)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.theme.isNotEmpty) Text('Tema: ${note.theme}'),
                    if (note.references.isNotEmpty)
                      Text('Versiculos: ${note.references}'),
                    const SizedBox(height: 8),
                    Text(note.notes.isEmpty ? 'Sem anotacoes.' : note.notes),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copySermonNote(note),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Exportar texto'),
                        ),
                        IconButton(
                          tooltip: note.favorite
                              ? 'Remover favorito'
                              : 'Marcar favorito',
                          onPressed: () {
                            setState(() {
                              _sermonNotes = _sermonNotes
                                  .map(
                                    (item) => identical(item, note)
                                        ? item.copyWith(
                                            favorite: !item.favorite,
                                          )
                                        : item,
                                  )
                                  .toList(growable: false);
                            });
                            _saveState();
                          },
                          icon: Icon(
                            note.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSearchTab() {
    final results = _searchResults;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Pesquisar palavra, frase, livro, personagem ou tema',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            setState(() {});
            _scheduleBibleSearch();
          },
          onSubmitted: (_) => _searchApiBible(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _searchModes.map((mode) {
            return ChoiceChip(
              label: Text(mode),
              selected: _searchMode == mode,
              onSelected: (_) => setState(() => _searchMode = mode),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _searchingBible ? null : _searchApiBible,
            icon: _searchingBible
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_outlined),
            label: const Text('Pesquisar na API.Bible'),
          ),
        ),
        const SizedBox(height: 16),
        if (_apiSearchResults.isNotEmpty) ...[
          Text(
            'Resultados API.Bible',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._apiSearchResults.map((verse) => _VerseTile(
                verse: verse,
                selected: verse.reference == _selectedReference,
                onTap: () => _selectVerseAndOpenActions(verse),
              )),
          const Divider(height: 32),
        ],
        ...results.map((verse) => _VerseTile(
              verse: verse,
              selected: verse.reference == _selectedReference,
              onTap: () => _selectVerseAndOpenActions(verse),
            )),
      ],
    );
  }

  Widget _buildPlansTab() {
    final plans = _allReadingPlans;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _createReadingPlan,
            icon: const Icon(Icons.add),
            label: const Text('Novo plano'),
          ),
        ),
        const SizedBox(height: 16),
        ...plans.map((plan) {
          final completed = plan.days.where(_history.contains).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Section(
              title: plan.title,
              subtitle: '${plan.days.length} dias - $completed concluidos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.description),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: completed / plan.days.length),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: plan.days
                        .map(
                          (reference) => ActionChip(
                            label: Text(reference),
                            avatar: Icon(
                              _history.contains(reference)
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                            ),
                            onPressed: () => _openReference(reference),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReferenceList(Set<String> references, String emptyText) {
    if (references.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: references
          .map(
            (reference) => _VerseTile(
              verse: _sampleVerses.firstWhere(
                (verse) => verse.reference == reference,
                orElse: () => _sampleVerses.first,
              ),
              selected: reference == _selectedReference,
              onTap: () => _selectVerseAndOpenActions(
                _sampleVerses.firstWhere(
                  (verse) => verse.reference == reference,
                  orElse: () => _sampleVerses.first,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNotesTab() {
    if (_notes.isEmpty) {
      return const Center(child: Text('Sem notas ainda.'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: _notes.entries.map((entry) {
        return ListTile(
          leading: const Icon(Icons.note_alt_outlined),
          title: Text(entry.key),
          subtitle: Text(entry.value),
          onTap: () {
            final verse = _sampleVerses.firstWhere(
              (verse) => verse.reference == entry.key,
              orElse: () => _sampleVerses.first,
            );
            _selectVerseAndOpenActions(verse);
          },
        );
      }).toList(),
    );
  }

  Widget _buildDevotionalsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: _devotionals.map((devotional) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Section(
            title: devotional.title,
            subtitle: devotional.reference,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(devotional.reflection),
                const SizedBox(height: 8),
                Text('Aplicacao: ${devotional.application}'),
                const SizedBox(height: 8),
                Text('Oracao: ${devotional.prayer}'),
                const SizedBox(height: 8),
                Text('Desafio: ${devotional.challenge}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssistantTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _assistantModes.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: _assistantMode == entry.key,
                onSelected: (_) => setState(() => _assistantMode = entry.key),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (_chat.isEmpty)
                _Section(
                  title: 'Assistente Biblico com IA',
                  subtitle:
                      'Explicacoes, estudos, celulas, esbocos, perguntas, devocionais, planos, oracao e aconselhamento biblico geral.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Explique Joao 3:16'),
                        onPressed: () => _askAssistant('Explique Joao 3:16.'),
                      ),
                      ActionChip(
                        label: const Text('Estudo sobre perdao'),
                        onPressed: () =>
                            _askAssistant('Crie um estudo sobre o perdao.'),
                      ),
                      ActionChip(
                        label: const Text('Celula sobre fe'),
                        onPressed: () => _askAssistant(
                          'Faca um estudo de 30 minutos sobre fe para celula.',
                        ),
                      ),
                    ],
                  ),
                ),
              ..._chat.map((message) => Align(
                    alignment: message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 680),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: message.fromUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      child: SelectableText(message.text),
                    ),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Pergunta ao Assistente Biblico',
                  ),
                  onSubmitted: (_) => _askAssistant(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busyAi ? null : _askAssistant,
                icon: _busyAi
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Enviar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('Sem historico de leitura ainda.'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: _history.map((reference) {
        final verse = _sampleVerses.firstWhere(
          (verse) => verse.reference == reference,
          orElse: () => _sampleVerses.first,
        );
        return _VerseTile(
          verse: verse,
          selected: reference == _selectedReference,
          onTap: () => _selectVerseAndOpenActions(verse),
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.brown.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withValues(alpha: 0.62),
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BibleTopHeader extends StatelessWidget {
  const _BibleTopHeader({
    required this.churchName,
    required this.reference,
    required this.text,
    required this.bibleLabel,
  });

  final String churchName;
  final String reference;
  final String text;
  final String? bibleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B21B6), Color(0xFF92400E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bíblia Comunhão',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        churchName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  side: BorderSide.none,
                  label: Text(
                    bibleLabel == null ? 'API.Bible' : 'Online',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              reference,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFFDE68A),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyHeroCard extends StatelessWidget {
  const _JourneyHeroCard({
    required this.readStreak,
    required this.prayerStreak,
    required this.completedPlans,
    required this.answeredPrayers,
    required this.score,
    required this.onMarkReading,
    required this.onMarkPrayer,
    required this.onAddGoal,
    required this.onAnsweredPrayer,
  });

  final int readStreak;
  final int prayerStreak;
  final int completedPlans;
  final int answeredPrayers;
  final int score;
  final VoidCallback onMarkReading;
  final VoidCallback onMarkPrayer;
  final VoidCallback onAddGoal;
  final VoidCallback onAnsweredPrayer;

  @override
  Widget build(BuildContext context) {
    final progress = (score / 14).clamp(0.08, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF7C2D12)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Color(0xFFFDE68A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jornada espiritual',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '$score pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Constância, oração, leitura e gratidão num só lugar.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: const Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(label: 'Leitura $readStreak d'),
              _HeroPill(label: 'Oração $prayerStreak d'),
              _HeroPill(label: 'Planos $completedPlans'),
              _HeroPill(label: 'Respondidas $answeredPrayers'),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onMarkReading,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Li hoje'),
              ),
              FilledButton.tonalIcon(
                onPressed: onMarkPrayer,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Orei hoje'),
              ),
              OutlinedButton.icon(
                onPressed: onAddGoal,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Meta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAnsweredPrayer,
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Gratidão'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ScriptureReaderCard extends StatelessWidget {
  const _ScriptureReaderCard({
    required this.verse,
    required this.bibleLabel,
    required this.loading,
    required this.favorite,
    required this.highlighted,
    required this.books,
    required this.chapters,
    required this.selectedBookId,
    required this.selectedChapterId,
    required this.selectedReference,
    required this.translation,
    required this.readerDarkMode,
    required this.offlineMode,
    required this.continuousScroll,
    required this.fontSize,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.onReferenceSubmitted,
    required this.onLocalReferenceChanged,
    required this.onFavorite,
    required this.onHighlight,
    required this.onShare,
    required this.onVerseTap,
    required this.onTranslationChanged,
    required this.onReaderDarkChanged,
    required this.onOfflineChanged,
    required this.onContinuousScrollChanged,
    required this.onFontSizeChanged,
  });

  final _BibleVerse verse;
  final String? bibleLabel;
  final bool loading;
  final bool favorite;
  final bool highlighted;
  final List<_BibleBook> books;
  final List<_BibleChapter> chapters;
  final String? selectedBookId;
  final String? selectedChapterId;
  final String selectedReference;
  final String translation;
  final bool readerDarkMode;
  final bool offlineMode;
  final bool continuousScroll;
  final double fontSize;
  final ValueChanged<String?> onBookChanged;
  final ValueChanged<String?> onChapterChanged;
  final ValueChanged<String> onReferenceSubmitted;
  final ValueChanged<String?> onLocalReferenceChanged;
  final VoidCallback onFavorite;
  final VoidCallback onHighlight;
  final VoidCallback onShare;
  final VoidCallback onVerseTap;
  final ValueChanged<String?> onTranslationChanged;
  final ValueChanged<bool> onReaderDarkChanged;
  final ValueChanged<bool> onOfflineChanged;
  final ValueChanged<bool> onContinuousScrollChanged;
  final ValueChanged<double> onFontSizeChanged;

  @override
  Widget build(BuildContext context) {
    final background = readerDarkMode ? const Color(0xFF111827) : Colors.white;
    final foreground =
        readerDarkMode ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final muted =
        readerDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) const LinearProgressIndicator(),
          Row(
            children: [
              Expanded(
                child: Text(
                  bibleLabel == null ? 'Leitura bíblica' : bibleLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Remover favorito' : 'Favoritar',
                onPressed: onFavorite,
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
              ),
              IconButton(
                tooltip: highlighted ? 'Remover destaque' : 'Destacar',
                onPressed: onHighlight,
                icon: Icon(
                  highlighted
                      ? Icons.border_color
                      : Icons.border_color_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: translation,
                  decoration: const InputDecoration(
                    labelText: 'Traducao',
                    prefixIcon: Icon(Icons.translate_outlined),
                  ),
                  items: _translations
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: onTranslationChanged,
                ),
              ),
              FilterChip(
                label: const Text('Offline'),
                avatar: const Icon(Icons.offline_bolt_outlined, size: 18),
                selected: offlineMode,
                onSelected: onOfflineChanged,
              ),
              FilterChip(
                label: const Text('Modo escuro'),
                avatar: const Icon(Icons.dark_mode_outlined, size: 18),
                selected: readerDarkMode,
                onSelected: onReaderDarkChanged,
              ),
              FilterChip(
                label: Text(
                  continuousScroll ? 'Rolagem continua' : 'Por capitulos',
                ),
                avatar: const Icon(Icons.view_agenda_outlined, size: 18),
                selected: continuousScroll,
                onSelected: onContinuousScrollChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Ir diretamente para capítulo ou versículo',
              hintText: 'Ex.: João 3:16 ou Salmos 23:1-6',
              prefixIcon: Icon(Icons.travel_explore_outlined),
              suffixIcon: Icon(Icons.keyboard_return_outlined),
            ),
            textInputAction: TextInputAction.go,
            onFieldSubmitted: onReferenceSubmitted,
          ),
          const SizedBox(height: 12),
          if (books.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final fields = [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBookId,
                    decoration: const InputDecoration(
                      labelText: 'Livro',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: books
                        .map(
                          (book) => DropdownMenuItem(
                            value: book.id,
                            child: Text(book.name),
                          ),
                        )
                        .toList(),
                    onChanged: onBookChanged,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedChapterId,
                    decoration: const InputDecoration(
                      labelText: 'Capítulo',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    items: chapters
                        .map(
                          (chapter) => DropdownMenuItem(
                            value: chapter.id,
                            child: Text(chapter.reference),
                          ),
                        )
                        .toList(),
                    onChanged: onChapterChanged,
                  ),
                ];
                if (narrow) {
                  return Column(
                    children: [
                      fields.first,
                      const SizedBox(height: 10),
                      fields.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: 12),
                    Expanded(child: fields.last),
                  ],
                );
              },
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedReference,
              decoration: const InputDecoration(
                labelText: 'Referência',
                prefixIcon: Icon(Icons.bookmark_outline),
              ),
              items: _sampleVerses
                  .map(
                    (verse) => DropdownMenuItem(
                      value: verse.reference,
                      child: Text(verse.reference),
                    ),
                  )
                  .toList(),
              onChanged: onLocalReferenceChanged,
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.format_size, color: muted),
              Expanded(
                child: Slider(
                  min: 16,
                  max: 30,
                  divisions: 7,
                  label: fontSize.round().toString(),
                  value: fontSize,
                  onChanged: onFontSizeChanged,
                ),
              ),
              Text(
                fontSize.round().toString(),
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verse.reference,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: readerDarkMode
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF5B21B6),
                ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onVerseTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                verse.text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: fontSize,
                      height: 1.48,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Partilhar'),
              ),
              FilledButton.tonalIcon(
                onPressed: onFavorite,
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                label: Text(favorite ? 'Favorito' : 'Favoritar'),
              ),
              OutlinedButton.icon(
                onPressed: onHighlight,
                icon: Icon(
                  highlighted
                      ? Icons.border_color
                      : Icons.border_color_outlined,
                ),
                label: Text(highlighted ? 'Destacado' : 'Destacar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF92400E)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SoftListTile extends StatelessWidget {
  const _SoftListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _VerseActionChip extends StatelessWidget {
  const _VerseActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    required this.verse,
    required this.selected,
    required this.onTap,
  });

  final _BibleVerse verse;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        selected: selected,
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(verse.reference),
        subtitle: Text(
          verse.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(label: Text(verse.theme)),
        onTap: onTap,
      ),
    );
  }
}

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BibleChatMessage {
  const _BibleChatMessage({
    required this.text,
    required this.fromUser,
  });

  factory _BibleChatMessage.user(String text) {
    return _BibleChatMessage(text: text, fromUser: true);
  }

  factory _BibleChatMessage.assistant(String text) {
    return _BibleChatMessage(text: text, fromUser: false);
  }

  final String text;
  final bool fromUser;
}

class _ThemeVerse {
  const _ThemeVerse({
    required this.reference,
    required this.text,
    required this.explanation,
  });

  final String reference;
  final String text;
  final String explanation;
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.category,
    required this.level,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  final String category;
  final String level;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
}

class _SermonNote {
  const _SermonNote({
    required this.title,
    required this.preacher,
    required this.date,
    required this.church,
    required this.theme,
    required this.references,
    required this.notes,
    required this.favorite,
  });

  factory _SermonNote.fromMap(Map<String, dynamic> map) {
    return _SermonNote(
      title: (map['title'] as String?) ?? 'Mensagem',
      preacher: (map['preacher'] as String?) ?? 'Nao informado',
      date: DateTime.tryParse((map['date'] as String?) ?? '') ?? DateTime.now(),
      church: (map['church'] as String?) ?? '',
      theme: (map['theme'] as String?) ?? '',
      references: (map['references'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      favorite: (map['favorite'] as bool?) ?? false,
    );
  }

  final String title;
  final String preacher;
  final DateTime date;
  final String church;
  final String theme;
  final String references;
  final String notes;
  final bool favorite;

  _SermonNote copyWith({bool? favorite}) {
    return _SermonNote(
      title: title,
      preacher: preacher,
      date: date,
      church: church,
      theme: theme,
      references: references,
      notes: notes,
      favorite: favorite ?? this.favorite,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'preacher': preacher,
        'date': date.toIso8601String(),
        'church': church,
        'theme': theme,
        'references': references,
        'notes': notes,
        'favorite': favorite,
      };
}

class _BibleVerse {
  const _BibleVerse({
    required this.reference,
    required this.text,
    required this.theme,
  });

  final String reference;
  final String text;
  final String theme;
}

class _BibleBook {
  const _BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory _BibleBook.fromMap(Map<String, dynamic> map) {
    return _BibleBook(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Livro',
      abbreviation: (map['abbreviation'] as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String abbreviation;
}

class _BibleChapter {
  const _BibleChapter({
    required this.id,
    required this.reference,
  });

  factory _BibleChapter.fromMap(Map<String, dynamic> map) {
    final reference = (map['reference'] as String?) ??
        (map['number'] == null ? 'Capitulo' : 'Capitulo ${map['number']}');
    return _BibleChapter(
      id: (map['id'] as String?) ?? '',
      reference: reference,
    );
  }

  final String id;
  final String reference;
}

class _ReadingPlan {
  const _ReadingPlan({
    required this.title,
    required this.description,
    required this.days,
  });

  factory _ReadingPlan.fromMap(Map<String, dynamic> map) {
    return _ReadingPlan(
      title: (map['title'] as String?) ?? 'Plano',
      description: (map['description'] as String?) ?? 'Plano criado por ti.',
      days: (map['days'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  final String title;
  final String description;
  final List<String> days;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'days': days,
      };
}

List<_ReadingPlan> _decodePlans(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => _ReadingPlan.fromMap(Map<String, dynamic>.from(item)))
        .where((plan) => plan.title.trim().isNotEmpty && plan.days.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

List<_SermonNote> _decodeSermonNotes(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => _SermonNote.fromMap(Map<String, dynamic>.from(item)))
        .where((note) => note.title.trim().isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

int _streakCount(List<String> days) {
  final normalized = days.toSet();
  var count = 0;
  var cursor = DateTime.now();
  while (true) {
    final key = cursor.toIso8601String().substring(0, 10);
    if (!normalized.contains(key)) break;
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

const _translations = <String>[
  'ARC',
  'ARA',
  'NVI',
  'KJV',
];

const _searchModes = <String>[
  'Palavra',
  'Frase',
  'Livro',
  'Personagem',
  'Tema',
];

const _highlightOptions = <String, Color>{
  'Promessas': Color(0xFFFACC15),
  'Esperanca': Color(0xFF22C55E),
  'Amor': Color(0xFFEF4444),
  'Fe': Color(0xFF3B82F6),
  'Profecias': Color(0xFFA855F7),
};

class _DevotionalEntry {
  const _DevotionalEntry({
    required this.title,
    required this.reference,
    required this.reflection,
    required this.application,
    required this.prayer,
    required this.challenge,
  });

  final String title;
  final String reference;
  final String reflection;
  final String application;
  final String prayer;
  final String challenge;
}

const _assistantModes = <String, String>{
  'explain': 'Explicar',
  'study': 'Estudo',
  'cell': 'Celula',
  'sermon': 'Pastor',
  'question': 'Perguntas',
  'devotional': 'Devocional',
  'reading_plan': 'Plano',
  'prayer': 'Oracao',
  'counsel': 'Aconselhamento',
};

const _quizCategories = <String>[
  'Antigo Testamento',
  'Novo Testamento',
  'Evangelhos',
  'Atos',
  'Cartas',
  'Profetas',
  'Reis',
  'Mulheres da Biblia',
  'Personagens Biblicos',
  'Parabolas',
  'Milagres',
  'Criancas',
  'Jovens',
];

const _quizLevels = <String>['Facil', 'Medio', 'Dificil'];

const _themeVerses = <String, List<_ThemeVerse>>{
  'Ansiedade': [
    _ThemeVerse(
      reference: 'Filipenses 4:6-7',
      text:
          'Nao andeis ansiosos por coisa alguma; em tudo, porem, sejam conhecidas diante de Deus as vossas peticoes.',
      explanation:
          'A ansiedade e levada a Deus em oracao, com gratidao e dependencia.',
    ),
    _ThemeVerse(
      reference: 'Mateus 6:34',
      text: 'Nao vos inquieteis com o dia de amanha.',
      explanation:
          'Jesus chama o discipulo a viver o dia presente com confianca.',
    ),
  ],
  'Fe': [
    _ThemeVerse(
      reference: 'Hebreus 11:1',
      text: 'A fe e a certeza de coisas que se esperam.',
      explanation:
          'Fe biblica envolve confianca em Deus mesmo antes de ver o resultado.',
    ),
  ],
  'Esperanca': [
    _ThemeVerse(
      reference: 'Romanos 8:28',
      text: 'Todas as coisas cooperam para o bem daqueles que amam a Deus.',
      explanation:
          'A esperanca crista descansa na soberania e bondade de Deus.',
    ),
  ],
  'Amor': [
    _ThemeVerse(
      reference: 'Joao 3:16',
      text:
          'Porque Deus amou o mundo de tal maneira que deu o seu Filho unico.',
      explanation: 'O amor de Deus se revela de forma sacrificial em Cristo.',
    ),
  ],
  'Perdao': [
    _ThemeVerse(
      reference: 'Efesios 4:32',
      text: 'Perdoando-vos uns aos outros, como tambem Deus vos perdoou.',
      explanation:
          'O perdao recebido de Deus torna-se modelo para perdoar o proximo.',
    ),
  ],
  'Familia': [
    _ThemeVerse(
      reference: 'Josue 24:15',
      text: 'Eu e a minha casa serviremos ao Senhor.',
      explanation:
          'A familia pode ser conduzida por uma decisao espiritual clara.',
    ),
  ],
  'Sabedoria': [
    _ThemeVerse(
      reference: 'Tiago 1:5',
      text: 'Se algum de vos necessita de sabedoria, peca-a a Deus.',
      explanation:
          'Deus convida seus filhos a pedir direcao com simplicidade e fe.',
    ),
  ],
  'Paz': [
    _ThemeVerse(
      reference: 'Joao 14:27',
      text: 'Deixo-vos a paz, a minha paz vos dou.',
      explanation: 'A paz de Cristo nao depende das circunstancias externas.',
    ),
  ],
  'Medo': [
    _ThemeVerse(
      reference: 'Isaias 41:10',
      text: 'Nao temas, porque eu sou contigo.',
      explanation:
          'A presenca de Deus e fundamento para coragem nos dias dificeis.',
    ),
  ],
  'Gratidao': [
    _ThemeVerse(
      reference: '1 Tessalonicenses 5:18',
      text: 'Em tudo dai gracas.',
      explanation:
          'Gratidao e uma pratica espiritual que reconhece a fidelidade de Deus.',
    ),
  ],
};

const _quizQuestions = <_QuizQuestion>[
  _QuizQuestion(
    category: 'Antigo Testamento',
    level: 'Facil',
    question: 'Qual foi o primeiro livro da Biblia?',
    options: ['Exodo', 'Genesis', 'Salmos', 'Josue'],
    correctAnswer: 'Genesis',
    explanation:
        'Genesis apresenta a criacao, os patriarcas e o inicio da historia biblica.',
  ),
  _QuizQuestion(
    category: 'Antigo Testamento',
    level: 'Medio',
    question: 'Quem interpretou os sonhos de Farao no Egito?',
    options: ['Daniel', 'Jose', 'Moises', 'Samuel'],
    correctAnswer: 'Jose',
    explanation:
        'Jose interpretou os sonhos de Farao e foi colocado em posicao de governo.',
  ),
  _QuizQuestion(
    category: 'Antigo Testamento',
    level: 'Dificil',
    question: 'Qual rei encontrou o livro da Lei durante a reforma do templo?',
    options: ['Ezequias', 'Josias', 'Uzias', 'Jotao'],
    correctAnswer: 'Josias',
    explanation:
        'No reinado de Josias, o livro da Lei foi encontrado e gerou arrependimento nacional.',
  ),
  _QuizQuestion(
    category: 'Novo Testamento',
    level: 'Facil',
    question: 'Quantos evangelhos existem no Novo Testamento?',
    options: ['3', '4', '5', '12'],
    correctAnswer: '4',
    explanation: 'Mateus, Marcos, Lucas e Joao sao os quatro evangelhos.',
  ),
  _QuizQuestion(
    category: 'Novo Testamento',
    level: 'Medio',
    question: 'Quem acompanhou Paulo em muitas viagens missionarias?',
    options: ['Barnabe', 'Saul', 'Pilatos', 'Caifas'],
    correctAnswer: 'Barnabe',
    explanation:
        'Barnabe foi um dos cooperadores importantes de Paulo no inicio da missao.',
  ),
  _QuizQuestion(
    category: 'Novo Testamento',
    level: 'Dificil',
    question: 'Em que ilha Joao recebeu a revelacao do Apocalipse?',
    options: ['Creta', 'Malta', 'Patmos', 'Chipre'],
    correctAnswer: 'Patmos',
    explanation:
        'Joao escreveu que recebeu a revelacao enquanto estava na ilha de Patmos.',
  ),
  _QuizQuestion(
    category: 'Evangelhos',
    level: 'Facil',
    question: 'Quem batizou Jesus?',
    options: ['Pedro', 'Joao Batista', 'Paulo', 'Moises'],
    correctAnswer: 'Joao Batista',
    explanation: 'Os evangelhos relatam que Joao Batista batizou Jesus.',
  ),
  _QuizQuestion(
    category: 'Evangelhos',
    level: 'Medio',
    question: 'Qual evangelho foi escrito por um medico?',
    options: ['Mateus', 'Marcos', 'Lucas', 'Joao'],
    correctAnswer: 'Lucas',
    explanation: 'Lucas era medico e escreveu o Evangelho de Lucas e Atos.',
  ),
  _QuizQuestion(
    category: 'Evangelhos',
    level: 'Dificil',
    question: 'Qual sinal marcou o inicio dos milagres de Jesus em Joao?',
    options: [
      'Cura do cego',
      'Agua transformada em vinho',
      'Multiplicacao dos paes',
      'Ressurreicao de Lazaro'
    ],
    correctAnswer: 'Agua transformada em vinho',
    explanation:
        'Joao 2 apresenta Caná da Galileia como o primeiro sinal de Jesus.',
  ),
  _QuizQuestion(
    category: 'Atos',
    level: 'Facil',
    question: 'O que aconteceu no dia de Pentecostes?',
    options: [
      'Nascimento de Moises',
      'Descida do Espirito Santo',
      'Construcao do templo',
      'Travessia do Jordao'
    ],
    correctAnswer: 'Descida do Espirito Santo',
    explanation:
        'Atos 2 relata a descida do Espirito Santo sobre os discipulos.',
  ),
  _QuizQuestion(
    category: 'Atos',
    level: 'Medio',
    question: 'Quem foi escolhido para substituir Judas entre os apostolos?',
    options: ['Estevao', 'Matias', 'Barnabe', 'Silas'],
    correctAnswer: 'Matias',
    explanation:
        'Matias foi escolhido em Atos 1 para ocupar o lugar deixado por Judas.',
  ),
  _QuizQuestion(
    category: 'Atos',
    level: 'Dificil',
    question: 'Quem explicou o evangelho ao eunuco etiope?',
    options: ['Pedro', 'Filipe', 'Paulo', 'Tiago'],
    correctAnswer: 'Filipe',
    explanation:
        'Filipe encontrou o eunuco em Atos 8 e explicou a passagem de Isaias.',
  ),
  _QuizQuestion(
    category: 'Cartas',
    level: 'Facil',
    question: 'Quem escreveu muitas cartas do Novo Testamento?',
    options: ['Paulo', 'Noe', 'Davi', 'Elias'],
    correctAnswer: 'Paulo',
    explanation: 'Paulo escreveu cartas a igrejas e lideres cristaos.',
  ),
  _QuizQuestion(
    category: 'Cartas',
    level: 'Medio',
    question: 'Qual carta fala do fruto do Espirito?',
    options: ['Galatas', 'Filemom', 'Judas', '3 Joao'],
    correctAnswer: 'Galatas',
    explanation: 'Galatas 5 descreve o fruto do Espirito.',
  ),
  _QuizQuestion(
    category: 'Cartas',
    level: 'Dificil',
    question: 'Qual carta enfatiza que a fe sem obras e morta?',
    options: ['Romanos', 'Tiago', 'Efesios', 'Filemom'],
    correctAnswer: 'Tiago',
    explanation: 'Tiago ensina que a fe viva se expressa em atitudes praticas.',
  ),
  _QuizQuestion(
    category: 'Profetas',
    level: 'Facil',
    question: 'Qual profeta foi engolido por um grande peixe?',
    options: ['Jonas', 'Isaias', 'Amos', 'Oseias'],
    correctAnswer: 'Jonas',
    explanation:
        'O livro de Jonas relata sua fuga e o grande peixe preparado por Deus.',
  ),
  _QuizQuestion(
    category: 'Profetas',
    level: 'Medio',
    question: 'Qual profeta teve a visao do vale de ossos secos?',
    options: ['Ezequiel', 'Jeremias', 'Miqueias', 'Habacuque'],
    correctAnswer: 'Ezequiel',
    explanation: 'Ezequiel 37 apresenta a visao do vale de ossos secos.',
  ),
  _QuizQuestion(
    category: 'Profetas',
    level: 'Dificil',
    question: 'Qual profeta confrontou Davi apos o pecado com Bate-Seba?',
    options: ['Nata', 'Gade', 'Samuel', 'Elias'],
    correctAnswer: 'Nata',
    explanation:
        'Nata confrontou Davi com uma parabola e o levou ao arrependimento.',
  ),
  _QuizQuestion(
    category: 'Reis',
    level: 'Facil',
    question: 'Quem foi o primeiro rei de Israel?',
    options: ['Saul', 'Davi', 'Salomao', 'Roboao'],
    correctAnswer: 'Saul',
    explanation: 'Saul foi ungido como primeiro rei de Israel.',
  ),
  _QuizQuestion(
    category: 'Reis',
    level: 'Medio',
    question: 'Qual rei pediu sabedoria a Deus?',
    options: ['Acabe', 'Salomao', 'Jeu', 'Manasses'],
    correctAnswer: 'Salomao',
    explanation: 'Salomao pediu sabedoria para governar o povo.',
  ),
  _QuizQuestion(
    category: 'Reis',
    level: 'Dificil',
    question: 'Qual rei viu a mao escrevendo na parede em Daniel 5?',
    options: ['Nabucodonosor', 'Belsazar', 'Ciro', 'Dario'],
    correctAnswer: 'Belsazar',
    explanation: 'Belsazar viu a escrita na parede durante um banquete.',
  ),
  _QuizQuestion(
    category: 'Mulheres da Biblia',
    level: 'Facil',
    question: 'Quem foi a mae de Jesus?',
    options: ['Marta', 'Maria', 'Ester', 'Rute'],
    correctAnswer: 'Maria',
    explanation: 'Maria foi escolhida para dar a luz Jesus.',
  ),
  _QuizQuestion(
    category: 'Mulheres da Biblia',
    level: 'Medio',
    question: 'Qual mulher disse: "o teu povo sera o meu povo"?',
    options: ['Rute', 'Debora', 'Ana', 'Abigail'],
    correctAnswer: 'Rute',
    explanation: 'Rute declarou fidelidade a Noemi e ao Deus de Israel.',
  ),
  _QuizQuestion(
    category: 'Mulheres da Biblia',
    level: 'Dificil',
    question: 'Quem julgava Israel debaixo de uma palmeira?',
    options: ['Hulda', 'Debora', 'Jael', 'Miria'],
    correctAnswer: 'Debora',
    explanation: 'Debora era profetisa e juiza em Israel.',
  ),
  _QuizQuestion(
    category: 'Personagens Biblicos',
    level: 'Facil',
    question: 'Quem construiu a arca?',
    options: ['Noe', 'Abraao', 'Isaque', 'Jaco'],
    correctAnswer: 'Noe',
    explanation: 'Noe construiu a arca em obediencia a Deus.',
  ),
  _QuizQuestion(
    category: 'Personagens Biblicos',
    level: 'Medio',
    question: 'Quem reconstruiu os muros de Jerusalem?',
    options: ['Neemias', 'Esdras', 'Salomao', 'Elias'],
    correctAnswer: 'Neemias',
    explanation:
        'Neemias liderou a reconstrucao dos muros e a organizacao do povo.',
  ),
  _QuizQuestion(
    category: 'Personagens Biblicos',
    level: 'Dificil',
    question: 'Quem foi chamado “amigo de Deus”?',
    options: ['Abraao', 'Josue', 'Gideao', 'Eli'],
    correctAnswer: 'Abraao',
    explanation:
        'Abraao e lembrado como amigo de Deus por sua fe e obediencia.',
  ),
  _QuizQuestion(
    category: 'Parabolas',
    level: 'Facil',
    question: 'Qual parabola fala de um homem que ajudou um ferido no caminho?',
    options: [
      'O semeador',
      'O bom samaritano',
      'A moeda perdida',
      'Os talentos'
    ],
    correctAnswer: 'O bom samaritano',
    explanation:
        'Jesus usou essa parabola para ensinar misericordia ao proximo.',
  ),
  _QuizQuestion(
    category: 'Parabolas',
    level: 'Medio',
    question: 'Qual parabola fala de um filho que voltou para casa?',
    options: [
      'O bom samaritano',
      'O filho prodigo',
      'O semeador',
      'As dez virgens',
    ],
    correctAnswer: 'O filho prodigo',
    explanation:
        'A parabola do filho prodigo destaca arrependimento, graca e restauracao.',
  ),
  _QuizQuestion(
    category: 'Parabolas',
    level: 'Dificil',
    question: 'Na parabola das dez virgens, o que faltou as cinco imprudentes?',
    options: ['Pao', 'Azeite', 'Agua', 'Moedas'],
    correctAnswer: 'Azeite',
    explanation:
        'Jesus ensinou vigilancia usando a imagem do azeite para as lampadas.',
  ),
  _QuizQuestion(
    category: 'Milagres',
    level: 'Facil',
    question: 'Jesus multiplicou paes e o que mais para alimentar a multidao?',
    options: ['Peixes', 'Uvas', 'Azeitonas', 'Mel'],
    correctAnswer: 'Peixes',
    explanation: 'Os evangelhos relatam a multiplicacao de paes e peixes.',
  ),
  _QuizQuestion(
    category: 'Milagres',
    level: 'Medio',
    question: 'Quem Jesus chamou para fora do tumulo?',
    options: ['Lazaro', 'Jairo', 'Bartimeu', 'Zaqueu'],
    correctAnswer: 'Lazaro',
    explanation: 'Joao 11 relata a ressurreicao de Lazaro.',
  ),
  _QuizQuestion(
    category: 'Milagres',
    level: 'Dificil',
    question: 'Em qual mar Jesus acalmou uma tempestade?',
    options: ['Mar Morto', 'Mar da Galileia', 'Mar Vermelho', 'Mediterraneo'],
    correctAnswer: 'Mar da Galileia',
    explanation:
        'Os discipulos estavam no barco no Mar da Galileia quando Jesus acalmou a tempestade.',
  ),
  _QuizQuestion(
    category: 'Criancas',
    level: 'Facil',
    question: 'Quem derrotou Golias ainda jovem?',
    options: ['Davi', 'Sansao', 'Saul', 'Jonatas'],
    correctAnswer: 'Davi',
    explanation: 'Davi confiou em Deus e venceu Golias.',
  ),
  _QuizQuestion(
    category: 'Criancas',
    level: 'Medio',
    question: 'Qual menino ouviu Deus chamando durante a noite?',
    options: ['Samuel', 'Ismael', 'Timoteo', 'Josias'],
    correctAnswer: 'Samuel',
    explanation: 'Samuel ouviu a voz de Deus enquanto servia com Eli.',
  ),
  _QuizQuestion(
    category: 'Criancas',
    level: 'Dificil',
    question: 'Qual rei comecou a reinar com oito anos?',
    options: ['Josias', 'Salomao', 'Acaz', 'Jeoacaz'],
    correctAnswer: 'Josias',
    explanation:
        'Josias era crianca quando comecou a reinar e depois liderou reforma espiritual.',
  ),
  _QuizQuestion(
    category: 'Jovens',
    level: 'Facil',
    question: 'Quem recusou contaminar-se com a comida do rei na Babilonia?',
    options: ['Daniel', 'Jonas', 'Elias', 'Gideao'],
    correctAnswer: 'Daniel',
    explanation: 'Daniel decidiu manter fidelidade a Deus mesmo longe de casa.',
  ),
  _QuizQuestion(
    category: 'Jovens',
    level: 'Medio',
    question:
        'Quem foi encorajado por Paulo a nao deixar que desprezassem sua mocidade?',
    options: ['Timoteo', 'Tito', 'Silas', 'Marcos'],
    correctAnswer: 'Timoteo',
    explanation:
        'Paulo orientou Timoteo a ser exemplo na palavra, conduta, amor, fe e pureza.',
  ),
  _QuizQuestion(
    category: 'Jovens',
    level: 'Dificil',
    question: 'Qual jovem caiu de uma janela enquanto Paulo pregava?',
    options: ['Eutico', 'Onesimo', 'Epafras', 'Tiquico'],
    correctAnswer: 'Eutico',
    explanation: 'Atos 20 relata que Eutico caiu da janela e foi restaurado.',
  ),
];

const _sampleVerses = <_BibleVerse>[
  _BibleVerse(
    reference: 'Joao 3:16',
    text:
        'Porque Deus amou o mundo de tal maneira que deu o seu Filho unico, para que todo o que nele crer nao pereca, mas tenha a vida eterna.',
    theme: 'salvacao',
  ),
  _BibleVerse(
    reference: 'Salmos 37:5',
    text: 'Entrega o teu caminho ao Senhor; confia nele, e ele tudo fara.',
    theme: 'confianca',
  ),
  _BibleVerse(
    reference: 'Filipenses 4:6-7',
    text:
        'Nao andeis ansiosos por coisa alguma; em tudo, porem, sejam conhecidas diante de Deus as vossas peticoes, pela oracao e pela suplica, com acoes de gracas.',
    theme: 'ansiedade',
  ),
  _BibleVerse(
    reference: 'Romanos 8:28',
    text:
        'Sabemos que todas as coisas cooperam para o bem daqueles que amam a Deus.',
    theme: 'esperanca',
  ),
  _BibleVerse(
    reference: 'Mateus 6:33',
    text:
        'Buscai, pois, em primeiro lugar, o seu Reino e a sua justica, e todas estas coisas vos serao acrescentadas.',
    theme: 'prioridade',
  ),
];

const _readingPlans = <_ReadingPlan>[
  _ReadingPlan(
    title: '7 dias de fe',
    description: 'Um plano curto para fortalecer confianca em Deus.',
    days: ['Joao 3:16', 'Salmos 37:5', 'Romanos 8:28'],
  ),
  _ReadingPlan(
    title: 'Paz contra ansiedade',
    description: 'Leituras para oracao, entrega e descanso.',
    days: ['Filipenses 4:6-7', 'Mateus 6:33', 'Salmos 37:5'],
  ),
];

const _devotionals = <_DevotionalEntry>[
  _DevotionalEntry(
    title: 'Confiar no caminho',
    reference: 'Salmos 37:5',
    reflection:
        'Confiar nao significa entender tudo. Significa entregar o caminho a Deus e dar o proximo passo com fidelidade.',
    application:
        'Antes de uma decisao importante, ore e procure conselho sabio.',
    prayer: 'Senhor, guia os meus passos e fortalece a minha confianca em ti.',
    challenge: 'Hoje ligue para alguem que precisa de encorajamento.',
  ),
  _DevotionalEntry(
    title: 'Paz em meio a pressao',
    reference: 'Filipenses 4:6-7',
    reflection:
        'A paz de Deus nao nega os problemas, mas guarda o coracao enquanto oramos com gratidao.',
    application: 'Escreva tres preocupacoes e transforme cada uma em oracao.',
    prayer: 'Deus de paz, ajuda-me a entregar o que nao consigo controlar.',
    challenge: 'Pratique cinco minutos de silencio e oracao hoje.',
  ),
];
