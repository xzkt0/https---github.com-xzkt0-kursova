import 'package:flutter/material.dart';

class DaySwipeView extends StatelessWidget {
  final PageController pageController;
  final List<String> days;
  final List<String> daysUkr;
  final Map<String, Map<int, List<Map<String, dynamic>>>> timetable;
  final Map<int, String> periodTimes;
  final bool isEvenWeek;
  final bool isTeacherView;

  const DaySwipeView({
    super.key,
    required this.pageController,
    required this.days,
    required this.daysUkr,
    required this.timetable,
    required this.periodTimes,
    required this.isEvenWeek,
    this.isTeacherView = false,
  });

  String get _weekFilter => isEvenWeek ? 'EVEN' : 'ODD';

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final periodMap = timetable[day] ?? {};

        final visiblePeriods = <int, List<Map<String, dynamic>>>{};
        for (int p = 1; p <= 6; p++) {
          final items = (periodMap[p] ?? [])
              .where((l) => l['evenodd'] == _weekFilter)
              .toList();
          if (items.isNotEmpty) visiblePeriods[p] = items;
        }

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
              if (visiblePeriods.isEmpty)
                const Expanded(
                  child: Center(child: Text('Немає занять')),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in visiblePeriods.entries)
                        for (final l in entry.value)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${entry.key}'),
                              ),
                              title: _buildLessonTitle(context, l),
                              subtitle: Text(periodTimes[entry.key]!),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLessonTitle(
      BuildContext context, Map<String, dynamic> l) {
    final firstLine = isTeacherView
        ? (l['group']?.toString() ?? '')
        : (l['teacher']?.toString() ?? '');
    final subject = l['subject']?.toString() ?? '';
    final type = l['type']?.toString() ?? '';
    final room = l['room']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (firstLine.isNotEmpty)
          Text(firstLine, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(subject),
        Text(
          '($type, $room)',
          style: TextStyle(
              fontSize: 13, color: Theme.of(context).colorScheme.secondary),
        ),
      ],
    );
  }
}
