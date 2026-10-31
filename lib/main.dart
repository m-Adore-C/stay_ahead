import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'models.dart';
import 'api_service.dart';
import 'auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  runApp(const StayAheadApp());
}

class StayAheadApp extends StatelessWidget {
  const StayAheadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayAhead',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          surface: Colors.white,
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  int _selectedIndex = 0;

  // --- API STATE VARIABLES ---
  String? _dailyQuote;
  bool _apiLoading = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _fetchApiData();
  }

  Future<void> _fetchApiData() async {
    setState(() {
      _apiLoading = true;
      _apiError = null;
    });

    try {
      final quote = await _apiService.fetchDailyQuote();
      if (!mounted) return;
      setState(() {
        _dailyQuote = quote;
        _apiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      final isNetworkError = errorMsg.contains('SocketException') ||
          errorMsg.contains('ClientException') ||
          errorMsg.contains('TimeoutException') ||
          errorMsg.contains('Failed host lookup');

      setState(() {
        _apiError = isNetworkError
            ? 'Unable to fetch daily quote. Check your connection.'
            : 'Unable to fetch daily quote (${errorMsg.replaceAll('Exception: ', '')})';
        _apiLoading = false;
      });
    }
  }

  Future<void> _saveCourseToFirestore(CourseModule course) async {
    try {
      await userCoursesRef().doc(course.id).update(course.toMap());
    } catch (e) {
      debugPrint('Error updating Firestore document: $e');
    }
  }

  // --- FILE STORAGE HANDLER ---
  Future<void> _pickAndSaveFile(CourseModule activeCourse) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg'],
    );

    if (!mounted) return;

    if (files.isNotEmpty) {
      final file = files.first;
      if (file.path != null) {
        final fileSize = await file.length() ?? 0;
        final newDoc = StoredDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: file.name,
          filePath: file.path!,
          fileSizeInBytes: fileSize,
        );

        activeCourse.documents.add(newDoc);
        await _saveCourseToFirestore(activeCourse);
      }
    }
  }

  // --- ADD COURSE DIALOG ---
  void _showAddCourseDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Software Architecture',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                await userCoursesRef().add({
                  'title': title,
                  'tasks': [],
                  'documents': [],
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            },
            child: const Text('Create Course'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  // --- EDIT COURSE DIALOG ---
  void _showEditCourseDialog(CourseModule course) {
    final titleController = TextEditingController(text: course.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Rename Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to rename this course?', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Course title...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != course.title) {
                course.title = newTitle;
                Navigator.pop(ctx);
                await _saveCourseToFirestore(course);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  // --- EDIT TASK DIALOG ---
  void _showEditTaskDialog(CourseModule activeCourse, CourseTask task) {
    final titleController = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Rename Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to rename this task?', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Task title...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != task.title) {
                task.title = newTitle;
                Navigator.pop(ctx);
                await _saveCourseToFirestore(activeCourse);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  // --- DELETE CONFIRMATION DIALOGS ---
  void _confirmDeleteCourse(String courseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this course? This action cannot be undone.', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCourse(courseId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(CourseModule activeCourse, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this file?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              activeCourse.documents.removeWhere((d) => d.id == docId);
              await _saveCourseToFirestore(activeCourse);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- ADD TASK DIALOG WITH DATE PICKER ---
  void _showAddTaskDialog(CourseModule activeCourse) {
    final titleController = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Task title...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedDate == null
                        ? 'No Due Date Selected'
                        : 'Due: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selectedDate == null ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      activeCourse.tasks.add(
                        CourseTask(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          dueDate: selectedDate,
                        ),
                      );
                      Navigator.pop(ctx);
                      await _saveCourseToFirestore(activeCourse);
                    }
                  },
                  child: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => titleController.dispose());
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await userCoursesRef().doc(courseId).delete();
    } catch (e) {
      debugPrint('Error deleting document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the currently signed-in user to display in the AppBar
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Unknown User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stay Ahead'),
        actions: [
          // Display currently signed in user
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const StayAheadApp()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<CourseModule>>(
        stream: userCoursesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading courses: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final modules = snapshot.data ?? [];

          if (_selectedIndex >= modules.length) {
            _selectedIndex = modules.isNotEmpty ? modules.length - 1 : 0;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- DAILY API CARD ---
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _apiLoading
                      ? const Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Loading daily motivation...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  )
                      : _apiError != null
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _apiError!,
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(70, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: _fetchApiData,
                        child: const Text('Retry', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Color(0xFF0F172A), size: 16),
                          SizedBox(width: 6),
                          Text('Daily Study Motivation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dailyQuote ?? '',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),

                if (modules.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.class_outlined, size: 40, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Courses Added Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start building your workspace by adding your first course module.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _showAddCourseDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Course'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // COURSE NAVIGATION CHIPS
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...List.generate(modules.length, (idx) {
                          final m = modules[idx];
                          final isSelected = _selectedIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedIndex = idx),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  m.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        IconButton.outlined(
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showAddCourseDialog,
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ACTIVE COURSE HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          modules[_selectedIndex].title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8)),
                            onPressed: () => _showEditCourseDialog(modules[_selectedIndex]),
                            tooltip: 'Rename Course',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
                            onPressed: () => _confirmDeleteCourse(modules[_selectedIndex].id),
                            tooltip: 'Delete Course',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),

                  // TASKS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tasks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      TextButton.icon(
                        onPressed: () => _showAddTaskDialog(modules[_selectedIndex]),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Task'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (modules[_selectedIndex].tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No tasks in this course.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    )
                  else
                    ...modules[_selectedIndex].tasks.map((task) {
                      Widget? reminderBadge;
                      if (task.isOverdue) {
                        reminderBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Text('OVERDUE', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        );
                      } else if (task.isDueToday) {
                        reminderBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Text('DUE TODAY', style: TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                        );
                      } else if (task.isDueSoon) {
                        reminderBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Text('DUE SOON', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                              color: task.status == TaskStatus.done ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (task.dueDate != null)
                                Text(
                                  'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              if (reminderBadge != null) ...[
                                const SizedBox(width: 8),
                                reminderBadge,
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () => _showEditTaskDialog(modules[_selectedIndex], task),
                                tooltip: 'Rename Task',
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<TaskStatus>(
                                value: task.status,
                                underline: const SizedBox(),
                                onChanged: (newStatus) async {
                                  if (newStatus != null) {
                                    task.status = newStatus;
                                    await _saveCourseToFirestore(modules[_selectedIndex]);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(value: TaskStatus.toDo, child: Text('To Do', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: TaskStatus.inProgress, child: Text('In Progress', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: TaskStatus.done, child: Text('Done', style: TextStyle(fontSize: 12))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // DOCUMENTS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Documents & Files', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _pickAndSaveFile(modules[_selectedIndex]),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Upload File', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (modules[_selectedIndex].documents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.folder_open, size: 32, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text('No documents uploaded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...modules[_selectedIndex].documents.map((doc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF0F172A)),
                          title: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(doc.formattedSize, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            onPressed: () => _confirmDeleteFile(modules[_selectedIndex], doc.id),
                            tooltip: 'Delete File',
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}