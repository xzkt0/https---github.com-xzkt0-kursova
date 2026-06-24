import 'package:flutter/material.dart';

class TeacherSelector extends StatelessWidget {
  final List<Map<String, dynamic>> filteredTeachers;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onDismiss;

  const TeacherSelector({
    super.key,
    required this.filteredTeachers,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withAlpha(100),
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: filteredTeachers.isEmpty
                  ? const Center(child: Text('Викладачів не знайдено'))
                  : ListView.builder(
                      itemCount: filteredTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = filteredTeachers[index];
                        return ListTile(
                          title: Text(teacher['fullname']),
                          onTap: () => onSelect(teacher),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
