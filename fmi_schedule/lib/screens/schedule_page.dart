import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/schedule_api.dart';
import '../widgets/group_selector.dart';
import '../widgets/teacher_selector.dart';
import '../widgets/table_view.dart';
import '../widgets/day_swipe_view.dart';
import 'settings_screen.dart';
import 'alarm_screen.dart';

class SchedulePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkTheme;

  const SchedulePage(
      {super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> filteredGroups = [];
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> filteredTeachers = [];

  Map<String, dynamic>? selectedGroup;
  Map<String, dynamic>? selectedTeacher;

  bool loadingGroups = false;
  bool loadingTeachers = false;
  bool loadingSchedule = false;

  Map<String, Map<int, List<Map<String, dynamic>>>> timetable = {};

  final Map<int, String> periodTimes = {
    1: '08:20 - 09:40',
    2: '09:50 - 11:10',
    3: '11:30 - 12:50',
    4: '13:00 - 14:20',
    5: '14:40 - 16:00',
    6: '16:10 - 17:30',
  };

  final List<String> days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
  ];

  final List<String> daysUkr = [
    'ПОНЕДІЛОК',
    'ВІВТОРОК',
    'СЕРЕДА',
    'ЧЕТВЕР',
    'П\'ЯТНИЦЯ',
  ];

  bool showGroupSelector = false;
  bool showTeacherSelector = false;
  bool isEvenWeek = true;
  bool isTableView = true;

  final TextEditingController groupController = TextEditingController();
  final TextEditingController teacherController = TextEditingController();

  late PageController pageController;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    final initialDay = (today >= 1 && today <= 5) ? today - 1 : 0;
    pageController = PageController(initialPage: initialDay);
    _loadGroupsAndTeachers();
    _loadLastGroup();
  }

  @override
  void dispose() {
    pageController.dispose();
    groupController.dispose();
    teacherController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadGroupsAndTeachers() async {
    setState(() {
      loadingGroups = true;
      loadingTeachers = true;
    });
    try {
      final groupData = await ScheduleApi.fetchGroupsWithId();
      final teacherData = await ScheduleApi.fetchTeachersWithId();
      setState(() {
        groups = groupData;
        filteredGroups = groupData;
        teachers = teacherData;
        filteredTeachers = teacherData;
      });
    } catch (e) {
      _showError('Не вдалось завантажити групи та викладачів. Перевірте з\'єднання.');
    } finally {
      setState(() {
        loadingGroups = false;
        loadingTeachers = false;
      });
    }
  }

  Future<void> _loadSchedule(int groupId) async {
    setState(() => loadingSchedule = true);
    try {
      final data = await ScheduleApi.fetchSchedule(groupId);
      _processScheduleData(data);
    } catch (e) {
      _showError('Не вдалось завантажити розклад');
      setState(() => loadingSchedule = false);
    }
  }

  Future<void> _loadScheduleByTeacher(String teacherName) async {
    setState(() => loadingSchedule = true);
    try {
      final data = await ScheduleApi.fetchScheduleByTeacher(teacherName);
      _processScheduleData(data);
    } catch (e) {
      _showError('Не вдалось завантажити розклад викладача');
      setState(() => loadingSchedule = false);
    }
  }

  void _processScheduleData(List<Map<String, dynamic>> data) {
    final temp = <String, Map<int, List<Map<String, dynamic>>>>{};
    for (final day in days) {
      temp[day] = {for (var i = 1; i <= 6; i++) i: []};
    }
    for (final item in data) {
      final day = item['day'];
      final period = item['period'];
      if (day is String &&
          period is int &&
          temp.containsKey(day) &&
          temp[day]!.containsKey(period)) {
        temp[day]![period]!.add(item);
      }
    }
    setState(() {
      timetable = temp;
      loadingSchedule = false;
    });
  }

  Future<void> _saveLastGroup(int groupId, String groupTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_group_id', groupId);
    await prefs.setString('last_group_title', groupTitle);
  }

  Future<void> _loadLastGroup() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('last_group_id')) {
      final id = prefs.getInt('last_group_id')!;
      final title = prefs.getString('last_group_title') ?? '';
      setState(() {
        selectedGroup = {'id': id, 'title': title};
        groupController.text = title;
      });
      _loadSchedule(id);
    }
  }

  Widget _buildSearchFields() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TextField(
            controller: groupController,
            decoration: InputDecoration(
              labelText: 'Введіть або оберіть групу',
              prefixIcon: loadingGroups
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.group),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (input) {
              setState(() {
                filteredGroups = groups.where((g) {
                  return g['title']
                      .toString()
                      .toLowerCase()
                      .contains(input.toLowerCase());
                }).toList();
                showGroupSelector = input.isNotEmpty;
                showTeacherSelector = false;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: teacherController,
            decoration: InputDecoration(
              labelText: 'Пошук за викладачем',
              prefixIcon: loadingTeachers
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.person),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (input) {
              setState(() {
                filteredTeachers = teachers.where((t) {
                  return t['fullname']
                      .toString()
                      .toLowerCase()
                      .contains(input.toLowerCase());
                }).toList();
                showTeacherSelector = input.isNotEmpty;
                showGroupSelector = false;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => isEvenWeek = !isEvenWeek),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child:
                    Text(isEvenWeek ? 'Парний тиждень' : 'Непарний тиждень'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() => isTableView = !isTableView),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                    isTableView ? 'Перегляд по днях' : 'Перегляд таблицею'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Розклад пар'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkTheme
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'Будильник',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlarmScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchFields(),
              Expanded(
                child: loadingSchedule
                    ? const Center(child: CircularProgressIndicator())
                    : timetable.isEmpty
                        ? const Center(child: Text('Розклад не завантажено'))
                        : isTableView
                            ? ScheduleTableView(
                                timetable: timetable,
                                days: days,
                                daysUkr: daysUkr,
                                periodTimes: periodTimes,
                                isEvenWeek: isEvenWeek,
                                isTeacherView: selectedTeacher != null,
                              )
                            : DaySwipeView(
                                pageController: pageController,
                                days: days,
                                daysUkr: daysUkr,
                                timetable: timetable,
                                periodTimes: periodTimes,
                                isEvenWeek: isEvenWeek,
                                isTeacherView: selectedTeacher != null,
                              ),
              ),
            ],
          ),
          if (showGroupSelector)
            GroupSelector(
              filteredGroups: filteredGroups,
              onSelect: (group) {
                setState(() {
                  selectedGroup = group;
                  groupController.text = group['title'];
                  showGroupSelector = false;
                  teacherController.clear();
                  selectedTeacher = null;
                });
                _loadSchedule(group['id']);
                _saveLastGroup(group['id'], group['title']);
              },
              onDismiss: () => setState(() => showGroupSelector = false),
            ),
          if (showTeacherSelector)
            TeacherSelector(
              filteredTeachers: filteredTeachers,
              onSelect: (teacher) {
                setState(() {
                  selectedTeacher = teacher;
                  teacherController.text = teacher['fullname'];
                  showTeacherSelector = false;
                  groupController.clear();
                  selectedGroup = null;
                });
                _loadScheduleByTeacher(teacher['fullname']);
              },
              onDismiss: () => setState(() => showTeacherSelector = false),
            ),
        ],
      ),
    );
  }
}
