import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// --- TASK STATUS ENUM ---
enum TaskStatus { toDo, inProgress, done }

class CourseTask {
  final String id;
  String title;
  DateTime? dueDate;
  TaskStatus status;

  CourseTask({
    required this.id,
    required this.title,
    this.dueDate,
    this.status = TaskStatus.toDo,
  });

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (dueDate == null || status == TaskStatus.done) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isDueSoon {
    if (dueDate == null || status == TaskStatus.done || isOverdue || isDueToday) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 2;
  }

  factory CourseTask.fromJson(Map<String, dynamic> json) {
    return CourseTask(
      id: json['id'] as String,
      title: json['title'] as String,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      status: TaskStatus.values[json['status'] ?? 0],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDate': dueDate?.toIso8601String(),
    'status': status.index,
  };
}

// --- STORED FILE MODEL ---
class StoredDocument {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSizeInBytes;

  StoredDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSizeInBytes,
  });

  String get formattedSize {
    if (fileSizeInBytes < 1024) return '$fileSizeInBytes B';
    if (fileSizeInBytes < 1048576) return '${(fileSizeInBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeInBytes / 1048576).toStringAsFixed(1)} MB';
  }

  factory StoredDocument.fromJson(Map<String, dynamic> json) {
    return StoredDocument(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileSizeInBytes: (json['fileSizeInBytes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'fileSizeInBytes': fileSizeInBytes,
  };
}

// --- COURSE MODULE MODEL ---
class CourseModule {
  final String id;
  String title;
  List<CourseTask> tasks;
  List<StoredDocument> documents;

  CourseModule({
    required this.id,
    required this.title,
    required this.tasks,
    required this.documents,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    var taskList = json['tasks'] as List? ?? [];
    var docList = json['documents'] as List? ?? [];
    return CourseModule(
      id: json['id'] as String,
      title: json['title'] as String,
      tasks: taskList.map((t) => CourseTask.fromJson(t)).toList(),
      documents: docList.map((d) => StoredDocument.fromJson(d)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'documents': documents.map((d) => d.toJson()).toList(),
  };
}

// --- LOCAL STORAGE SERVICE ---
class LocalStorageService {
  static const String _storageKey = 'stayahead_workspace_v1';

  // Starts with 0 courses by default so the user builds from scratch
  static final List<CourseModule> defaultModules = [];

  Future<List<CourseModule>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) {
      await saveCourses(defaultModules);
      return defaultModules;
    }
    final List decoded = jsonDecode(data);
    return decoded.map((item) => CourseModule.fromJson(item)).toList();
  }

  Future<void> saveCourses(List<CourseModule> modules) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(modules.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}