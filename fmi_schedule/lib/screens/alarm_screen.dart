import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/user_preferences.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../widgets/address_search_field.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _monitoringActive = false;
  bool _alarmEnabled = false;
  DateTime? _nextAlarmTime;
  DateTime? _lastCheckTime;
  int _monitorStartHour = 6;
  int _monitorStartMinute = 30;
  bool _loading = false;
  bool _checkLoading = false;
  bool _initialLoading = true;
  DateTime? _mockClassTime;
  TransportMode _transportMode = TransportMode.walking;
  String? _homeAddress;
  int? _routeMinutes;
  bool _routeCalculating = false;
  bool _demoAlarmLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadState().then((_) => _calculateRoute());
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final status = await LocationService.requestPermission();
    if (!mounted) return;
    if (status == LocationStatus.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Дозвіл на локацію заблоковано — відкрийте налаштування'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Налаштування',
            onPressed: LocationService.openSettings,
          ),
        ),
      );
    } else if (status == LocationStatus.serviceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS вимкнено — увімкніть геолокацію на пристрої'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (status == LocationStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дозвіл на локацію не надано — буде використано центр міста'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadState() async {
    final prefs = await UserPreferences.load();
    final active = await UserPreferences.isMonitoringActive();
    final alarmTime = await UserPreferences.getLastAlarmTime();
    final checkTime = await UserPreferences.getLastCheckTime();
    final startTime = await UserPreferences.getMonitorStartTime();
    final mockClass = await UserPreferences.getMockClassTime();
    final transportMode = await UserPreferences.getTransportMode();
    final homeAddress = await UserPreferences.getHomeAddress();

    setState(() {
      _alarmEnabled = (prefs?['alarmEnabled'] as bool?) ?? false;
      _monitoringActive = active;
      _nextAlarmTime = alarmTime;
      _lastCheckTime = checkTime;
      _monitorStartHour = startTime.hour;
      _monitorStartMinute = startTime.minute;
      _mockClassTime = mockClass;
      _transportMode = transportMode;
      _homeAddress = homeAddress;
      _initialLoading = false;
    });
  }

  Future<void> _calculateRoute() async {
    final homeCoords = await UserPreferences.getHomeAddressCoords();
    if (homeCoords == null) {
      if (mounted) setState(() => _routeMinutes = null);
      return;
    }
    if (mounted) setState(() => _routeCalculating = true);
    try {
      final minutes = await RouteService.getRouteToFaculty(
        _transportMode,
        fromCoords: homeCoords,
      );
      if (mounted) setState(() => _routeMinutes = minutes);
    } catch (_) {
      if (mounted) setState(() => _routeMinutes = null);
    } finally {
      if (mounted) setState(() => _routeCalculating = false);
    }
  }

  Future<void> _toggleMonitoring() async {
    setState(() => _loading = true);
    try {
      if (_monitoringActive) {
        await AlarmService.deactivate();
        setState(() {
          _monitoringActive = false;
          _nextAlarmTime = null;
          _lastCheckTime = null;
        });
      } else {
        final locStatus = await LocationService.requestPermission();
        if (locStatus == LocationStatus.deniedForever && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Дозвіл на локацію заблоковано'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Налаштування',
                onPressed: LocationService.openSettings,
              ),
            ),
          );
        } else if (locStatus != LocationStatus.granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS недоступний — буде використано центр міста'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await AlarmService.activate();
        final alarmTime = await UserPreferences.getLastAlarmTime();
        setState(() {
          _monitoringActive = true;
          _nextAlarmTime = alarmTime;
          _lastCheckTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: _monitorStartHour, minute: _monitorStartMinute),
      helpText: 'Час початку моніторингу',
    );
    if (picked == null) return;
    await UserPreferences.saveMonitorStartTime(picked.hour, picked.minute);
    setState(() {
      _monitorStartHour = picked.hour;
      _monitorStartMinute = picked.minute;
    });
  }

  Future<void> _toggleMockClass() async {
    if (_mockClassTime != null) {
      await UserPreferences.clearMockClassTime();
      setState(() => _mockClassTime = null);
    } else {
      final mockTime = DateTime.now().add(const Duration(hours: 1));
      await UserPreferences.setMockClassTime(mockTime);
      setState(() => _mockClassTime = mockTime);
    }
  }

  Future<void> _triggerDemoAlarm() async {
    setState(() => _demoAlarmLoading = true);
    // Грає звук будильника одразу
    FlutterRingtonePlayer().playAlarm(looping: true);
    if (mounted) setState(() => _demoAlarmLoading = false);
    // Показуємо діалог — закрити можна тільки натиснувши кнопку
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('⏰ Час вставати!'),
          content: const Text('Демо-будильник спрацював'),
          actions: [
            TextButton(
              onPressed: () {
                FlutterRingtonePlayer().stop();
                NotificationService.cancelAlarm();
                Navigator.of(ctx).pop();
              },
              child: const Text('Вимкнути будильник'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _runManualCheck() async {
    setState(() => _checkLoading = true);
    try {
      // Визначаємо origin: домашні координати → GPS → показуємо джерело
      final homeCoords = await UserPreferences.getHomeAddressCoords();
      String locationInfo;

      if (homeCoords != null) {
        // Є збережена домашня адреса з координатами — GPS не потрібен
        locationInfo = _homeAddress ?? 'домашня адреса';
      } else {
        // Немає домашньої адреси — пробуємо GPS
        final result = await LocationService.requestAndGetPosition();
        if (result.status == LocationStatus.deniedForever && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Дозвіл на локацію заблоковано'),
              action: SnackBarAction(
                label: 'Налаштування',
                onPressed: LocationService.openSettings,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (!result.hasLocation && mounted) {
          final detail =
              result.debugError != null ? ': ${result.debugError}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'GPS недоступний$detail — вкажіть домашню адресу для точного розрахунку',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        locationInfo = result.coords != null ? 'GPS' : 'мок (немає адреси/GPS)';
      }

      await AlarmService.runManualCheck();
      final alarmTime = await UserPreferences.getLastAlarmTime();
      setState(() {
        _nextAlarmTime = alarmTime;
        _lastCheckTime = DateTime.now();
      });

      if (mounted && alarmTime != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Будильник на ${_fmt(alarmTime)} • $locationInfo'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Будильник'),
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildAlarmTimeCard(),
                  const SizedBox(height: 16),
                  _buildSettingsCard(),
                  const SizedBox(height: 16),
                  _buildTransportCard(),
                  const SizedBox(height: 16),
                  _buildMockClassCard(),
                  const SizedBox(height: 16),
                  _buildDemoAlarmButton(),
                  const SizedBox(height: 24),
                  _buildCheckNowButton(),
                  const SizedBox(height: 12),
                  _buildActivateButton(),
                  if (!_alarmEnabled) ...[
                    const SizedBox(height: 16),
                    _buildAlarmDisabledNote(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final color = _monitoringActive ? Colors.green : Colors.grey;
    final icon =
        _monitoringActive ? Icons.sensors : Icons.sensors_off_outlined;
    final label =
        _monitoringActive ? 'Моніторинг активний' : 'Моніторинг вимкнено';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: _lastCheckTime != null
            ? Text('Остання перевірка: ${_fmt(_lastCheckTime!)}')
            : const Text('Перевірок ще не було'),
        trailing: _monitoringActive
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              )
            : null,
      ),
    );
  }

  Widget _buildAlarmTimeCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.alarm, size: 36, color: Colors.blueAccent),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Розрахований час будильника',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _nextAlarmTime != null ? _fmt(_nextAlarmTime!) : '—',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    final startStr =
        '${_monitorStartHour.toString().padLeft(2, '0')}:${_monitorStartMinute.toString().padLeft(2, '0')}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Час початку моніторингу'),
            subtitle: Text(startStr),
            trailing: const Icon(Icons.chevron_right),
            onTap: _monitoringActive ? null : _pickStartTime,
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Інтервал перевірок'),
            subtitle: Text('Кожні 15 хв (обмеження Android)'),
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Адреса відправлення ---
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 20),
                const SizedBox(width: 10),
                const Text('Домашня адреса (origin)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _homeAddress != null
                      ? Icons.check_circle_outline
                      : Icons.gps_fixed,
                  size: 14,
                  color: _homeAddress != null
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _homeAddress != null
                        ? 'Маршрут від: $_homeAddress'
                        : 'Маршрут від: поточної геолокації',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AddressSearchField(
              key: ValueKey(_homeAddress ?? 'home-empty'),
              initialValue: _homeAddress,
              hintText: 'напр. вул. Шевченка 1, Чернівці',
              prefixIcon: Icons.home_outlined,
              onSelected: (address, lat, lng) async {
                await UserPreferences.saveHomeAddress(
                  address,
                  lat: lat,
                  lng: lng,
                );
                setState(() => _homeAddress = address);
                _calculateRoute();
              },
              onCleared: () async {
                await UserPreferences.clearHomeAddress();
                setState(() {
                  _homeAddress = null;
                  _routeMinutes = null;
                });
              },
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // --- Спосіб пересування ---
            Row(
              children: [
                const Icon(Icons.route, size: 20),
                const SizedBox(width: 10),
                const Text('Спосіб пересування',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransportMode>(
              segments: const [
                ButtonSegment(
                  value: TransportMode.walking,
                  icon: Icon(Icons.directions_walk),
                  label: Text('Пішки'),
                ),
                ButtonSegment(
                  value: TransportMode.car,
                  icon: Icon(Icons.directions_car),
                  label: Text('Авто'),
                ),
                ButtonSegment(
                  value: TransportMode.transit,
                  icon: Icon(Icons.directions_bus),
                  label: Text('Транспорт'),
                ),
              ],
              selected: {_transportMode},
              onSelectionChanged: (set) async {
                final mode = set.first;
                await UserPreferences.saveTransportMode(mode);
                setState(() => _transportMode = mode);
                _calculateRoute();
              },
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            ),

            // --- Результат розрахунку маршруту ---
            if (_homeAddress != null) ...[
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _routeCalculating
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: LinearProgressIndicator(),
                      )
                    : _routeMinutes != null
                        ? Container(
                            key: ValueKey(_routeMinutes),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withAlpha(120),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _transportMode == TransportMode.walking
                                      ? Icons.directions_walk
                                      : _transportMode == TransportMode.car
                                          ? Icons.directions_car
                                          : Icons.directions_bus,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'До ФМІ: $_routeMinutes хв',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMockClassCard() {
    final isOn = _mockClassTime != null;
    final subtitle = isOn
        ? 'Активна: о ${_fmt(_mockClassTime!)} (через ~${_mockClassTime!.difference(DateTime.now()).inMinutes} хв)'
        : 'Вимкнено';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isOn
          ? Colors.amber.withAlpha(30)
          : null,
      child: SwitchListTile(
        secondary: Icon(
          Icons.science_outlined,
          color: isOn ? Colors.amber.shade700 : Colors.grey,
        ),
        title: Text(
          'Демо-пара',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isOn ? Colors.amber.shade700 : null,
          ),
        ),
        subtitle: Text(subtitle),
        value: isOn,
        onChanged: (_) => _toggleMockClass(),
      ),
    );
  }

  Widget _buildCheckNowButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: (_checkLoading || !_alarmEnabled) ? null : _runManualCheck,
        icon: _checkLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: const Text('Перевірити зараз'),
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildActivateButton() {
    final isOn = _monitoringActive;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: (_loading || !_alarmEnabled) ? null : _toggleMonitoring,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(isOn
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline),
        label: Text(
          isOn ? 'Зупинити моніторинг' : 'Активувати моніторинг',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOn ? Colors.red.shade600 : Colors.blueAccent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildDemoAlarmButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _demoAlarmLoading ? null : _triggerDemoAlarm,
        icon: _demoAlarmLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.notifications_active_outlined),
        label: const Text('Задзвонити зараз (демо)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange.shade700,
          side: BorderSide(color: Colors.orange.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmDisabledNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Будильник вимкнено у налаштуваннях профілю. '
              'Увімкніть його у "Налаштуваннях" щоб використовувати моніторинг.',
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
