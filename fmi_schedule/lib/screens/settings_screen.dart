import 'package:flutter/material.dart';
import '../services/user_preferences.dart';
import '../services/user_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _email;
  bool _alarmEnabled = false;
  int _prepMinutes = 30;
  int _bufferMinutes = 10;
  bool _loading = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final data = await UserPreferences.load();
    if (!mounted) return;
    setState(() {
      _email = data?['email'] as String?;
      _alarmEnabled = (data?['alarmEnabled'] as bool?) ?? false;
      _prepMinutes = (data?['prepMinutes'] as int?) ?? 30;
      _bufferMinutes = (data?['bufferMinutes'] as int?) ?? 10;
      _initialLoading = false;
    });
  }

  Future<void> _save() async {
    if (_email == null) return;
    setState(() => _loading = true);

    try {
      await UserApi.updateUser(
        email: _email!,
        alarmEnabled: _alarmEnabled,
        prepMinutes: _prepMinutes,
        bufferMinutes: _bufferMinutes,
      );
      await UserPreferences.save(
        email: _email!,
        alarmEnabled: _alarmEnabled,
        prepMinutes: _prepMinutes,
        bufferMinutes: _bufferMinutes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Налаштування збережено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(_email ?? '—'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text('Інтерактивний будильник'),
                      subtitle: const Text(
                          'Розраховує час підйому за розкладом'),
                      secondary: const Icon(Icons.alarm),
                      value: _alarmEnabled,
                      onChanged: (v) => setState(() => _alarmEnabled = v),
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _alarmEnabled
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _StepperRow(
                                label:
                                    'Час від пробудження до виходу',
                                value: _prepMinutes,
                                unit: 'хв',
                                min: 5,
                                max: 120,
                                step: 5,
                                onChanged: (v) =>
                                    setState(() => _prepMinutes = v),
                              ),
                              const SizedBox(height: 16),
                              _StepperRow(
                                label: 'Запас часу (буфер)',
                                value: _bufferMinutes,
                                unit: 'хв',
                                min: 0,
                                max: 30,
                                step: 5,
                                onChanged: (v) =>
                                    setState(() => _bufferMinutes = v),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Зберегти',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: value > min ? () => onChanged(value - step) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Icon(Icons.remove, size: 18),
            ),
            const SizedBox(width: 16),
            Text(
              '$value $unit',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: value < max ? () => onChanged(value + step) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
