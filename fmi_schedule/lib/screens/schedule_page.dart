import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/schedule_api.dart';

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

  List<Map<String, dynamic>> schedule = [];
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
  int initialDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadGroupsAndTeachers();
    _loadLastGroup();
    _initTodayPage();
  }

  Future<void> _initTodayPage() async {
    final today = DateTime.now().weekday;
    initialDayIndex = (today >= 1 && today <= 5) ? today - 1 : 0;
    pageController = PageController(initialPage: initialDayIndex);
  }

  Future<void> _loadGroupsAndTeachers() async {
    try {
      final groupData = await ScheduleApi.fetchGroupsWithId();
      final teacherData = await ScheduleApi.fetchTeachersWithId();
      setState(() {
        groups = groupData;
        filteredGroups = groupData;
        teachers = teacherData;
        filteredTeachers = teacherData;
      });
      print('✅ Groups loaded: ${groups.length}');
      print('✅ Teachers loaded: ${teachers.length}');
    } catch (e) {
      print('❌ Error loading groups or teachers: $e');
    }
  }

  Future<void> _loadSchedule(int groupId) async {
    try {
      setState(() {
        loadingSchedule = true;
      });
      final data = await ScheduleApi.fetchSchedule(groupId);
      _processScheduleData(data);
    } catch (e) {
      print('Error loading schedule: $e');
      setState(() => loadingSchedule = false);
    }
  }

  Future<void> _loadScheduleByTeacher(String teacherName) async {
    try {
      setState(() {
        loadingSchedule = true;
      });
      final data = await ScheduleApi.fetchScheduleByTeacher(teacherName);
      _processScheduleData(data);
    } catch (e) {
      print('Error loading teacher schedule: $e');
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
      schedule = data;
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

  String buildLessonText(Map<String, dynamic> l) {
    return '${l['teacher']}\n${l['subject']}\n(${l['type']}, ${l['room']})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Розклад пар'),
        actions: [
          IconButton(
            icon: Icon(
                widget.isDarkTheme ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              setState(() {
                isTableView = !isTableView;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    TextField(
                      controller: groupController,
                      decoration: InputDecoration(
                        labelText: 'Введіть або оберіть групу',
                        prefixIcon: const Icon(Icons.group),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      onChanged: (input) {
                        setState(() {
                          filteredGroups = groups.where((group) {
                            final title =
                                group['title'].toString().toLowerCase();
                            return title.contains(input.toLowerCase());
                          }).toList();
                          showGroupSelector = input.isNotEmpty;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: teacherController,
                      decoration: InputDecoration(
                        labelText: 'Пошук за викладачем',
                        prefixIcon: const Icon(Icons.person),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      onChanged: (input) {
                        setState(() {
                          filteredTeachers = teachers.where((teacher) {
                            final fullname =
                                teacher['fullname'].toString().toLowerCase();
                            return fullname.contains(input.toLowerCase());
                          }).toList();
                          showTeacherSelector = input.isNotEmpty;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() => isEvenWeek = !isEvenWeek);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(isEvenWeek
                              ? 'Парний тиждень'
                              : 'Непарний тиждень'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isTableView = !isTableView;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(isTableView
                              ? 'Перегляд по днях'
                              : 'Перегляд таблицею'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loadingSchedule
                    ? const Center(child: CircularProgressIndicator())
                    : timetable.isEmpty
                        ? const Center(child: Text('Розклад не завантажено'))
                        : isTableView
                            ? buildTableView()
                            : buildDaySwipeView(),
              ),
            ],
          ),
          if (showGroupSelector) buildGroupSelector(),
          if (showTeacherSelector) buildTeacherSelector(),
        ],
      ),
    );
  }

  Widget buildGroupSelector() => Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => showGroupSelector = false),
          child: Container(
            color: Colors.black.withAlpha(100),
            child: Center(
              child: Material(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return ListTile(
                        title: Text(group['title']),
                        onTap: () {
                          setState(() {
                            selectedGroup = group;
                            groupController.text = group['title'];
                            showGroupSelector = false;
                          });
                          _loadSchedule(group['id']);
                          _saveLastGroup(group['id'], group['title']);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget buildTeacherSelector() => Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => showTeacherSelector = false),
          child: Container(
            color: Colors.black.withAlpha(100),
            child: Center(
              child: Material(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.builder(
                    itemCount: filteredTeachers.length,
                    itemBuilder: (context, index) {
                      final teacher = filteredTeachers[index];
                      return ListTile(
                        title: Text(teacher['fullname']),
                        onTap: () {
                          setState(() {
                            selectedTeacher = teacher;
                            teacherController.text = teacher['fullname'];
                            showTeacherSelector = false;
                          });
                          _loadScheduleByTeacher(teacher['fullname']);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.black26),
        defaultColumnWidth: const FixedColumnWidth(180),
        children: [
          TableRow(
            children: [
              const TableCell(child: SizedBox()),
              ...days.map(
                (day) => TableCell(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (int i = 1; i <= 6; i++)
            TableRow(
              children: [
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '$i\n${periodTimes[i]}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ...days.map((day) {
                  final lessons = (timetable[day]?[i] ?? []).where((lesson) {
                    if (isEvenWeek) {
                      return lesson['evenodd'] == 'EVEN';
                    } else {
                      return lesson['evenodd'] == 'ODD';
                    }
                  }).toList();

                  if (lessons.isEmpty) {
                    return const TableCell(
                      child: SizedBox(height: 50),
                    );
                  }

                  final l = lessons.first;
                  return TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        buildLessonText(l),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget buildDaySwipeView() {
    return PageView.builder(
      controller: pageController,
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final lessons = timetable[day] ?? {};

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                daysUkr[index],
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: lessons.length,
                  itemBuilder: (context, periodIndex) {
                    final period = periodIndex + 1;
                    final items = (lessons[period] ?? []).where((lesson) {
                      if (isEvenWeek) {
                        return lesson['evenodd'] == 'EVEN';
                      } else {
                        return lesson['evenodd'] == 'ODD';
                      }
                    }).toList();

                    if (items.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final l = items.first;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(buildLessonText(l)),
                        subtitle: Text(periodTimes[period]!),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
