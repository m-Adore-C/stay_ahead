import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
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
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      fileSizeInBytes: (json['fileSizeInBytes'] as num?)?.toInt() ?? 0,
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
  DateTime? createdAt;

  CourseModule({
    required this.id,
    required this.title,
    required this.tasks,
    required this.documents,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'documents': documents.map((d) => d.toJson()).toList(),
  };

  factory CourseModule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? {};
  var taskList = data['tasks'] as List? ?? [];
  var docList = data['documents'] as List? ?? [];

  return CourseModule(
  id: doc.id,
  title: data['title'] as String? ?? 'Untitled Course',
  tasks: taskList.map((t) => CourseTask.fromJson(Map<String, dynamic>.from(t))).toList(),
  documents: docList.map((d) => StoredDocument.fromJson(Map<String, dynamic>.from(d))).toList(),
  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  );
  }
}

// Collection reference for current logged-in user's courses
CollectionReference<Map<String, dynamic>> userCoursesRef() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user found');
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('courses');
}

// Step 4: Live Stream of courses sorted by creation date
Stream<List<CourseModule>> userCoursesStream() {
  return userCoursesRef()
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => CourseModule.fromDoc(doc)).toList());
}