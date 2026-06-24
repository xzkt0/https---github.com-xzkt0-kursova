import 'package:flutter/material.dart';
import '../services/user_preferences.dart';
import '../services/user_api.dart';
import 'schedule_page.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkTheme;

  const OnboardingScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkTheme,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  int _step = 0; // 0 = email, 1 = alarm settings

  bool _alarmEnabled = false;
  int _prepMinutes = 30;
  int _bufferMinutes = 10;
  bool _loading = false;

  static final _emailRegex =
      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final email = _emailController.text.trim();

    try {
      await UserApi.register(
        email: email,
        alarmEnabled: _alarmEnabled,
        prepMinutes: _prepMinutes,
        bufferMinutes: _bufferMinutes,
      );
      await UserPreferences.save(
        email: email,
        alarmEnabled: _alarmEnabled,
        prepMinutes: _prepMinutes,
        bufferMinutes: _bufferMinutes,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SchedulePage(
            toggleTheme: widget.toggleTheme,
            isDarkTheme: widget.isDarkTheme,
          ),
        ),
      );
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
      appBar: AppBar(
        title: const Text('Ласкаво просимо'),
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkTheme
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _step == 0
              ? _buildEmailStep()
              : _buildAlarmStep(),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('email-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Крок 1 з 2',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Введіть ваш email',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Для збереження налаштувань та синхронізації',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email обов\'язковий';
              }
              if (!_emailRegex.hasMatch(v.trim())) {
                return 'Введіть коректний email';
              }
              return null;
            },
            onFieldSubmitted: (_) => _nextStep(),
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Далі', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmStep() {
    return Column(
      key: const ValueKey('alarm-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Крок 2 з 2',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Налаштування будильника',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Розраховує час підйому з урахуванням маршруту',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 28),

        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            title: const Text('Інтерактивний будильник'),
            subtitle:
                const Text('Сповіщення на основі розкладу та трафіку'),
            secondary: const Icon(Icons.alarm),
            value: _alarmEnabled,
            onChanged: (v) => setState(() => _alarmEnabled = v),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _alarmEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StepperRow(
                        label: 'Час від пробудження до виходу',
                        value: _prepMinutes,
                        unit: 'хв',
                        min: 5,
                        max: 120,
                        step: 5,
                        onChanged: (v) => setState(() => _prepMinutes = v),
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
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
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
                : const Text('Зберегти та продовжити',
                    style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
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
