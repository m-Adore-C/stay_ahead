import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';
import 'api_service.dart';

void main() {
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
      home: const DashboardScreen(),
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
  final LocalStorageService _storageService = LocalStorageService();
  final ApiService _apiService = ApiService();

  List<CourseModule> _modules = [];
  int _selectedIndex = 0;
  bool _isLoading = true;

  // --- API STATE VARIABLES ---
  String? _dailyQuote;
  bool _apiLoading = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchApiData();
  }

  Future<void> _loadData() async {
    final data = await _storageService.loadCourses();
    if (!mounted) return;
    setState(() {
      _modules = data;
      if (_selectedIndex >= _modules.length) {
        _selectedIndex = 0;
      }
      _isLoading = false;
    });
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

  void _saveState() {
    _storageService.saveCourses(_modules);
    setState(() {});
  }

  // --- FILE STORAGE HANDLER ---
  Future<void> _pickAndSaveFile() async {
    if (_modules.isEmpty || _selectedIndex >= _modules.length) return;

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg'],
    );

    if (!mounted) return;

    if (files.isNotEmpty) {
      final file = files.first;
      if (file.path != null) {
        final fileSize = file.lengthSync() ?? await file.length() ?? 0;
        final newDoc = StoredDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: file.name,
          filePath: file.path!,
          fileSizeInBytes: fileSize,
        );

        _modules[_selectedIndex].documents.add(newDoc);
        _saveState();
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
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final newCourse = CourseModule(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  tasks: [],
                  documents: [],
                );
                setState(() {
                  _modules.add(newCourse);
                  _selectedIndex = _modules.length - 1;
                });
                _saveState();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create Course'),
          ),
        ],
      ),
    ).then((_) => titleController.dispose());
  }

  // --- ADD TASK DIALOG WITH DATE PICKER ---
  void _showAddTaskDialog() {
    if (_modules.isEmpty || _selectedIndex >= _modules.length) return;
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
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      _modules[_selectedIndex].tasks.add(
                        CourseTask(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          dueDate: selectedDate,
                        ),
                      );
                      _saveState();
                      Navigator.pop(ctx);
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

  void _deleteCurrentCourse() {
    if (_modules.isEmpty) return;
    setState(() {
      _modules.removeAt(_selectedIndex);
      if (_selectedIndex >= _modules.length) {
        _selectedIndex = _modules.isNotEmpty ? _modules.length - 1 : 0;
      }
    });
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'StayAhead',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LIVE API CARD / NO-INTERNET ERROR & RETRY ---
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

            if (_modules.isEmpty)
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
                    ...List.generate(_modules.length, (idx) {
                      final m = _modules[idx];
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
                      _modules[_selectedIndex < _modules.length ? _selectedIndex : 0].title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
                    onPressed: _deleteCurrentCourse,
                    tooltip: 'Delete Course',
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
                    onPressed: _showAddTaskDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_modules[_selectedIndex].tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('No tasks in this course.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                )
              else
                ..._modules[_selectedIndex].tasks.map((task) {
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
                      trailing: DropdownButton<TaskStatus>(
                        value: task.status,
                        underline: const SizedBox(),
                        onChanged: (newStatus) {
                          if (newStatus != null) {
                            task.status = newStatus;
                            _saveState();
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: TaskStatus.toDo, child: Text('To Do', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: TaskStatus.inProgress, child: Text('In Progress', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: TaskStatus.done, child: Text('Done', style: TextStyle(fontSize: 12))),
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
                    onPressed: _pickAndSaveFile,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload File', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_modules[_selectedIndex].documents.isEmpty)
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
                ..._modules[_selectedIndex].documents.map((doc) {
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
                        onPressed: () {
                          _modules[_selectedIndex].documents.removeWhere((d) => d.id == doc.id);
                          _saveState();
                        },
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}