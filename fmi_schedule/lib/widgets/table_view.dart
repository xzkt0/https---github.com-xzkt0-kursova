import 'package:flutter/material.dart';

class ScheduleTableView extends StatelessWidget {
  final Map<String, Map<int, List<Map<String, dynamic>>>> timetable;
  final List<String> days;
  final List<String> daysUkr;
  final Map<int, String> periodTimes;
  final bool isEvenWeek;
  final bool isTeacherView;

  const ScheduleTableView({
    super.key,
    required this.timetable,
    required this.days,
    required this.daysUkr,
    required this.periodTimes,
    required this.isEvenWeek,
    this.isTeacherView = false,
  });

  String get _weekFilter => isEvenWeek ? 'EVEN' : 'ODD';

  String _lessonText(Map<String, dynamic> l) {
    final firstLine = isTeacherView
        ? (l['group']?.toString() ?? '')
        : (l['teacher']?.toString() ?? '');
    final subject = l['subject']?.toString() ?? '';
    final type = l['type']?.toString() ?? '';
    final room = l['room']?.toString() ?? '';
    return '$firstLine\n$subject\n($type, $room)';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.black26),
        defaultColumnWidth: const FixedColumnWidth(180),
        children: [
          TableRow(
            children: [
              const TableCell(child: SizedBox()),
              ...List.generate(
                days.length,
                (i) => TableCell(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        daysUkr[i],
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (int period = 1; period <= 6; period++)
            TableRow(
              children: [
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '$period\n${periodTimes[period]}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ...days.map((day) {
                  final lessons = (timetable[day]?[period] ?? [])
                      .where((l) => l['evenodd'] == _weekFilter)
                      .toList();

                  if (lessons.isEmpty) {
                    return const TableCell(child: SizedBox(height: 50));
                  }

                  return TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final l in lessons) ...[
                            Text(
                              _lessonText(l),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                            if (l != lessons.last)
                              const Divider(height: 6, thickness: 0.5),
                          ],
                        ],
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
}
