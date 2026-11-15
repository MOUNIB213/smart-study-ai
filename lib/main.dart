import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database;
  runApp(const SmartStudyApp());
}

class SmartStudyApp extends StatelessWidget {
  const SmartStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مساعدي الدراسي الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6F5C),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF289672),
        brightness: Brightness.dark,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}

class LessonModel {
  final int? id;
  final String title;
  final String createdAt;
  final String extractedText;
  final String? summary;
  final String? mindMapJson;
  final String? quizJson;
  final String? examJson;

  LessonModel({
    this.id,
    required this.title,
    required this.createdAt,
    required this.extractedText,
    this.summary,
    this.mindMapJson,
    this.quizJson,
    this.examJson,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'extractedText': extractedText,
        'summary': summary,
        'mindMapJson': mindMapJson,
        'quizJson': quizJson,
        'examJson': examJson,
      };

  factory LessonModel.fromMap(Map<String, dynamic> map) => LessonModel(
        id: map['id'] as int?,
        title: map['title'] as String,
        createdAt: map['createdAt'] as String,
        extractedText: map['extractedText'] as String? ?? '',
        summary: map['summary'] as String?,
        mindMapJson: map['mindMapJson'] as String?,
        quizJson: map['quizJson'] as String?,
        examJson: map['examJson'] as String?,
      );

  LessonModel copyWith({
    String? title,
    String? extractedText,
    String? summary,
    String? mindMapJson,
    String? quizJson,
    String? examJson,
  }) {
    return LessonModel(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      extractedText: extractedText ?? this.extractedText,
      summary: summary ?? this.summary,
      mindMapJson: mindMapJson ?? this.mindMapJson,
      quizJson: quizJson ?? this.quizJson,
      examJson: examJson ?? this.examJson,
    );
  }
}

class AttachmentModel {
  final int? id;
  final int lessonId;
  final String fileName;
  final String filePath;
  final String mimeType;

  AttachmentModel({
    this.id,
    required this.lessonId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'fileName': fileName,
        'filePath': filePath,
        'mimeType': mimeType,
      };

  factory AttachmentModel.fromMap(Map<String, dynamic> map) => AttachmentModel(
        id: map['id'] as int?,
        lessonId: map['lessonId'] as int,
        fileName: map['fileName'] as String,
        filePath: map['filePath'] as String,
        mimeType: map['mimeType'] as String,
      );
}

class ChatMessageModel {
  final int? id;
  final int? lessonId;
  final String role;
  final String content;
  final String createdAt;

  ChatMessageModel({
    this.id,
    this.lessonId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'role': role,
        'content': content,
        'createdAt': createdAt,
      };

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) =>
      ChatMessageModel(
        id: map['id'] as int?,
        lessonId: map['lessonId'] as int?,
        role: map['role'] as String,
        content: map['content'] as String,
        createdAt: map['createdAt'] as String,
      );
}

class AppSettingsService {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = 'gemini_api_key';
  static const _modelNameKey = 'gemini_model_name';

  static Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey.trim());
  }

  static Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  static Future<void> saveModelName(String modelName) async {
    await _storage.write(key: _modelNameKey, value: modelName.trim());
  }

  static Future<String> getModelName() async {
    final model = await _storage.read(key: _modelNameKey);
    return (model == null || model.isEmpty) ? 'gemini-2.5-flash' : model;
  }
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_study_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        extractedText TEXT NOT NULL,
        summary TEXT,
        mindMapJson TEXT,
        quizJson TEXT,
        examJson TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lessonId INTEGER NOT NULL,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        FOREIGN KEY (lessonId) REFERENCES lessons (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lessonId INTEGER,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertLesson(LessonModel lesson) async {
    final db = await instance.database;
    return await db.insert('lessons', lesson.toMap());
  }

  Future<int> updateLesson(LessonModel lesson) async {
    final db = await instance.database;
    return await db.update('lessons', lesson.toMap(), where: 'id = ?', whereArgs: [lesson.id]);
  }

  Future<void> deleteLesson(int id) async {
    final db = await instance.database;
    final attachments = await getAttachmentsForLesson(id);
    for (final att in attachments) {
      final f = File(att.filePath);
      if (await f.exists()) await f.delete();
    }
    await db.delete('attachments', where: 'lessonId = ?', whereArgs: [id]);
    await db.delete('chat_messages', where: 'lessonId = ?', whereArgs: [id]);
    await db.delete('lessons', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<LessonModel>> getAllLessons() async {
    final db = await instance.database;
    final result = await db.query('lessons', orderBy: 'id DESC');
    return result.map((e) => LessonModel.fromMap(e)).toList();
  }

  Future<LessonModel?> getLessonById(int id) async {
    final db = await instance.database;
    final result = await db.query('lessons', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return LessonModel.fromMap(result.first);
  }

  Future<int> insertAttachment(AttachmentModel attachment) async {
    final db = await instance.database;
    return await db.insert('attachments', attachment.toMap());
  }

  Future<List<AttachmentModel>> getAttachmentsForLesson(int lessonId) async {
    final db = await instance.database;
    final result = await db.query('attachments', where: 'lessonId = ?', whereArgs: [lessonId]);
    return result.map((e) => AttachmentModel.fromMap(e)).toList();
  }

  Future<int> insertChatMessage(ChatMessageModel msg) async {
    final db = await instance.database;
    return await db.insert('chat_messages', msg.toMap());
  }

  Future<List<ChatMessageModel>> getChatMessages(int? lessonId) async {
    final db = await instance.database;
    final result = lessonId == null
        ? await db.query('chat_messages', where: 'lessonId IS NULL', orderBy: 'id ASC')
        : await db.query('chat_messages', where: 'lessonId = ?', whereArgs: [lessonId], orderBy: 'id ASC');
    return result.map((e) => ChatMessageModel.fromMap(e)).toList();
  }

  Future<void> clearChatMessages(int? lessonId) async {
    final db = await instance.database;
    if (lessonId == null) {
      await db.delete('chat_messages', where: 'lessonId IS NULL');
    } else {
      await db.delete('chat_messages', where: 'lessonId = ?', whereArgs: [lessonId]);
    }
  }
}

class AiStudyService {
  static Future<GenerativeModel> _getModel({bool jsonOutput = false}) async {
    final apiKey = await AppSettingsService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('يرجى إضافة مفتاح الذكاء الاصطناعي (API Key) من إعدادات التطبيق أولاً.');
    }
    final modelName = await AppSettingsService.getModelName();
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        responseMimeType: jsonOutput ? 'application/json' : 'text/plain',
      ),
    );
  }

  static Future<String> extractTextFromPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text.trim();
  }

  static Future<List<Part>> _buildLessonParts(
    LessonModel lesson,
    List<AttachmentModel> attachments,
    String instruction,
  ) async {
    final List<Part> parts = [TextPart(instruction)];
    if (lesson.extractedText.trim().isNotEmpty) {
      parts.add(TextPart('\n--- النص المستخرج (${lesson.title}) ---\n${lesson.extractedText}\n'));
    }
    for (final att in attachments) {
      final file = File(att.filePath);
      if (await file.exists()) {
        if (att.mimeType.startsWith('image/') || att.mimeType == 'application/pdf') {
          final Uint8List bytes = await file.readAsBytes();
          parts.add(DataPart(att.mimeType, bytes));
        }
      }
    }
    return parts;
  }

  static Future<String> transcribeImagesIfNeeded(List<AttachmentModel> attachments) async {
    final imageAttachments = attachments.where((a) => a.mimeType.startsWith('image/')).toList();
    if (imageAttachments.isEmpty) return '';
    final model = await _getModel(jsonOutput: false);
    final List<Part> parts = [
      TextPart('قم بقراءة وتفريغ كافة النصوص المكتوبة في هذه الصور الدراسية بدقة عالية:'),
    ];
    for (final img in imageAttachments) {
      final f = File(img.filePath);
      if (await f.exists()) {
        parts.add(DataPart(img.mimeType, await f.readAsBytes()));
      }
    }
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? '';
  }

  static Future<String> generateSummary(LessonModel lesson, List<AttachmentModel> attachments) async {
    final model = await _getModel(jsonOutput: false);
    const prompt = 'انطلاقاً من الصور والملفات المرفقة فقط، أنشئ ملخصاً دراسياً شاملاً ومنظماً يتضمن الفكرة العامة، المفاهيم الأساسية، الشرح التفصيلي، وأهم نقاط المراجعة.';
    final parts = await _buildLessonParts(lesson, attachments, prompt);
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? 'تعذر إنشاء الملخص.';
  }

  static Future<String> generateMindMapJson(LessonModel lesson, List<AttachmentModel> attachments) async {
    final model = await _getModel(jsonOutput: true);
    const prompt = '''
انطلاقاً من محتوى هذا الدرس فقط، أنشئ خريطة ذهنية شاملة بصيغة JSON حصراً وفق الهيكل:
{"title": "عنوان الدرس", "summary": "وصف مختصر", "branches": [{"title": "محور", "details": "شرح", "subNodes": [{"title": "فكرة فرعية", "points": ["نقطة 1"]}]}]}
''';
    final parts = await _buildLessonParts(lesson, attachments, prompt);
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? '{}';
  }

  static Future<String> generateQuizJson(LessonModel lesson, List<AttachmentModel> attachments) async {
    final model = await _getModel(jsonOutput: true);
    const prompt = '''
انطلاقاً من محتوى هذا الدرس فقط، أنشئ كويز تفاعلي مكون من 8 أسئلة اختيار من متعدد بصيغة JSON حصراً:
{"questions": [{"question": "السؤال؟", "options": ["1", "2", "3", "4"], "correctIndex": 0, "explanation": "الشرح"}]}
''';
    final parts = await _buildLessonParts(lesson, attachments, prompt);
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? '{"questions": []}';
  }

  static Future<String> generateExamJson(LessonModel lesson, List<AttachmentModel> attachments) async {
    final model = await _getModel(jsonOutput: true);
    const prompt = '''
انطلاقاً من محتوى هذا الدرس فقط، صمم امتحاناً شاملاً على 20 نقطة بصيغة JSON حصراً:
{"examTitle": "امتحان شامل", "durationMinutes": 45, "totalPoints": 20, "trueFalseQuestions": [{"statement": "عبارة", "isTrue": true, "points": 2, "justification": "تعليل"}], "mcqQuestions": [{"question": "سؤال", "options": ["أ", "ب", "ج", "د"], "correctIndex": 0, "points": 2, "explanation": "توضيح"}], "essayQuestions": [{"question": "سؤال مقالي", "points": 4, "modelAnswer": "الإجابة النموذجية"}]}
''';
    final parts = await _buildLessonParts(lesson, attachments, prompt);
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? '{}';
  }

  static Future<String> askFromFiles({
    required String question,
    LessonModel? specificLesson,
    required List<ChatMessageModel> history,
  }) async {
    final model = await _getModel(jsonOutput: false);
    final List<Part> parts = [
      TextPart('أجب عن سؤال الطالب استناداً إلى الملفات والدروس المرفقة أدناه فقط مع ذكر اسم الدرس:'),
    ];
    if (specificLesson != null) {
      final attachments = await LocalDatabase.instance.getAttachmentsForLesson(specificLesson.id!);
      parts.addAll(await _buildLessonParts(specificLesson, attachments, 'مرجع الدرس: ${specificLesson.title}'));
    } else {
      final allLessons = await LocalDatabase.instance.getAllLessons();
      for (final lesson in allLessons) {
        parts.add(TextPart('\n=== [درس: ${lesson.title}] ===\n${lesson.extractedText}\n${lesson.summary ?? ""}\n'));
      }
    }
    parts.add(TextPart('\nسؤال الطالب: $question'));
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? 'لم أتمكن من توليد إجابة.';
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LessonModel> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final lessons = await LocalDatabase.instance.getAllLessons();
    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مساعدي الدراسي الذكي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyChatScreen(lesson: null))),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
              ? const Center(child: Text('اضغط على زر الإضافة لتصوير درس أو رفع ملف'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    return Card(
                      child: ListTile(
                        title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(lesson.createdAt.split('T').first),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (lesson.id != null) {
                              await LocalDatabase.instance.deleteLesson(lesson.id!);
                              _refreshData();
                            }
                          },
                        ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => LessonDetailScreen(lessonId: lesson.id!)));
                          _refreshData();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddLessonBottomSheet(),
          );
          if (created == true) _refreshData();
        },
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('إضافة درس'),
      ),
    );
  }
}

class AddLessonBottomSheet extends StatefulWidget {
  const AddLessonBottomSheet({super.key});
  @override
  State<AddLessonBottomSheet> createState() => _AddLessonBottomSheetState();
}

class _AddLessonBottomSheetState extends State<AddLessonBottomSheet> {
  final _titleController = TextEditingController();
  final List<File> _selectedFiles = [];
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _saveLesson() async {
    if (_titleController.text.trim().isEmpty || _selectedFiles.isEmpty) return;
    setState(() => _isSaving = true);
    final appDir = await getApplicationDocumentsDirectory();
    final lessonsDir = Directory(p.join(appDir.path, 'lessons_files'));
    if (!await lessonsDir.exists()) await lessonsDir.create(recursive: true);

    final StringBuffer extracted = StringBuffer();
    final lessonId = await LocalDatabase.instance.insertLesson(
      LessonModel(title: _titleController.text.trim(), createdAt: DateTime.now().toIso8601String(), extractedText: ''),
    );

    final List<AttachmentModel> atts = [];
    for (final file in _selectedFiles) {
      final savedPath = p.join(lessonsDir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}');
      final savedFile = await file.copy(savedPath);
      final ext = p.extension(savedFile.path).toLowerCase();
      final mime = ext == '.pdf' ? 'application/pdf' : 'image/jpeg';
      if (mime == 'application/pdf') {
        try {
          extracted.writeln(await AiStudyService.extractTextFromPdf(savedFile));
        } catch (_) {}
      }
      final att = AttachmentModel(lessonId: lessonId, fileName: p.basename(file.path), filePath: savedFile.path, mimeType: mime);
      await LocalDatabase.instance.insertAttachment(att);
      atts.add(att);
    }

    try {
      final ocr = await AiStudyService.transcribeImagesIfNeeded(atts);
      if (ocr.isNotEmpty) extracted.writeln(ocr);
    } catch (_) {}

    await LocalDatabase.instance.updateLesson(
      LessonModel(id: lessonId, title: _titleController.text.trim(), createdAt: DateTime.now().toIso8601String(), extractedText: extracted.toString()),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'عنوان الدرس')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final photo = await _imagePicker.pickImage(source: ImageSource.camera);
                    if (photo != null) setState(() => _selectedFiles.add(File(photo.path)));
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('تصوير بالكاميرا'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final files = await FilePicker.pickFiles();
                    if (files.isNotEmpty) setState(() => _selectedFiles.addAll(files.where((f) => f.path != null).map((f) => File(f.path!))));
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('رفع ملفات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _isSaving ? null : _saveLesson, child: const Text('حفظ الدرس محلياً')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class LessonDetailScreen extends StatefulWidget {
  final int lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});
  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LessonModel? _lesson;
  List<AttachmentModel> _attachments = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final l = await LocalDatabase.instance.getLessonById(widget.lessonId);
    final a = await LocalDatabase.instance.getAttachmentsForLesson(widget.lessonId);
    if (mounted) setState(() { _lesson = l; _attachments = a; });
  }

  Future<void> _runTask(Future<LessonModel> Function() task) async {
    setState(() => _busy = true);
    try {
      final updated = await task();
      await LocalDatabase.instance.updateLesson(updated);
      if (mounted) setState(() => _lesson = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lesson == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson!.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'الملخص'),
            Tab(text: 'خريطة ذهنية'),
            Tab(text: 'كويز'),
            Tab(text: 'امتحان'),
            Tab(text: 'اسأل الدرس'),
          ],
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _lesson!.summary == null
                    ? Center(child: FilledButton(onPressed: () => _runTask(() async => _lesson!.copyWith(summary: await AiStudyService.generateSummary(_lesson!, _attachments))), child: const Text('توليد الملخص')))
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_lesson!.summary!, style: const TextStyle(fontSize: 15, height: 1.6))),
                _lesson!.mindMapJson == null
                    ? Center(child: FilledButton(onPressed: () => _runTask(() async => _lesson!.copyWith(mindMapJson: await AiStudyService.generateMindMapJson(_lesson!, _attachments))), child: const Text('توليد الخريطة الذهنية')))
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_lesson!.mindMapJson!)),
                _lesson!.quizJson == null
                    ? Center(child: FilledButton(onPressed: () => _runTask(() async => _lesson!.copyWith(quizJson: await AiStudyService.generateQuizJson(_lesson!, _attachments))), child: const Text('توليد الكويز')))
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_lesson!.quizJson!)),
                _lesson!.examJson == null
                    ? Center(child: FilledButton(onPressed: () => _runTask(() async => _lesson!.copyWith(examJson: await AiStudyService.generateExamJson(_lesson!, _attachments))), child: const Text('توليد الامتحان')))
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_lesson!.examJson!)),
                StudyChatScreen(lesson: _lesson, embedded: true),
              ],
            ),
    );
  }
}

class StudyChatScreen extends StatefulWidget {
  final LessonModel? lesson;
  final bool embedded;
  const StudyChatScreen({super.key, required this.lesson, this.embedded = false});
  @override
  State<StudyChatScreen> createState() => _StudyChatScreenState();
}

class _StudyChatScreenState extends State<StudyChatScreen> {
  final _ctrl = TextEditingController();
  List<ChatMessageModel> _msgs = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await LocalDatabase.instance.getChatMessages(widget.lesson?.id);
    if (mounted) setState(() => _msgs = m);
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _sending) return;
    _ctrl.clear();
    await LocalDatabase.instance.insertChatMessage(ChatMessageModel(lessonId: widget.lesson?.id, role: 'user', content: q, createdAt: DateTime.now().toIso8601String()));
    await _load();
    setState(() => _sending = true);
    try {
      final ans = await AiStudyService.askFromFiles(question: q, specificLesson: widget.lesson, history: _msgs);
      await LocalDatabase.instance.insertChatMessage(ChatMessageModel(lessonId: widget.lesson?.id, role: 'model', content: ans, createdAt: DateTime.now().toIso8601String()));
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => ListTile(
              title: SelectableText(_msgs[i].content),
              subtitle: Text(_msgs[i].role == 'user' ? 'أنت' : 'المعلم الذكي'),
            ),
          ),
        ),
        if (_sending) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'اسأل عن أي شيء في ملفاتك...'))),
              IconButton(onPressed: _send, icon: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
    return widget.embedded ? body : Scaffold(appBar: AppBar(title: const Text('اسأل ملفاتك')), body: body);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppSettingsService.getApiKey().then((v) => _keyCtrl.text = v ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات مفتاح الـ AI')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'Gemini API Key', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await AppSettingsService.saveApiKey(_keyCtrl.text);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ محلياً')));
              },
              child: const Text('حفظ المفتاح محلياً'),
            ),
          ],
        ),
      ),
    );
  }
}
