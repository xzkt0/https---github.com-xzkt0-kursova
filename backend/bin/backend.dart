import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

late PostgreSQLConnection _db;

// Парсинг рядка "1322s" → секунди
int _parseSeconds(String? s) {
  if (s == null) return 0;
  return int.tryParse(s.replaceAll('s', '').trim()) ?? 0;
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};

Middleware _corsMiddleware() {
  return createMiddleware(
    requestHandler: (request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (response) {
      return response.change(headers: {...response.headers, ..._corsHeaders});
    },
  );
}

class ScheduleData {
  static Map<String, dynamic>? _cachedData;
  static DateTime? _lastFetch;
  static String _semesterId = '57';

  static String get apiUrl =>
      'https://fmi-schedule.chnu.edu.ua/schedules/full/semester?semesterId=$_semesterId';

  static void configure({required String semesterId}) {
    _semesterId = semesterId;
  }

  static Future<Map<String, dynamic>> fetchScheduleData() async {
    if (_cachedData != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inHours < 1) {
      return _cachedData!;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch schedule data: ${response.statusCode}',
        );
      }

      final raw = jsonDecode(response.body);
      _cachedData = {
        'groups': _extractGroups(raw),
        'scheduleGroups': _extractScheduleGroups(raw),
      };
      _lastFetch = DateTime.now();
      return _cachedData!;
    } catch (e) {
      print('Error fetching schedule data: $e');
      if (_cachedData != null) {
        print('Using cached data');
        return _cachedData!;
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> getGroups() {
    return _groups
        .map(_groupInfo)
        .where((group) => group['id'] != null && group['title'] != null)
        .map((group) => {'id': group['id'], 'title': group['title']})
        .toList();
  }

  static List<Map<String, dynamic>> getTeachers() {
    final teacherSet = <String>{};

    for (final group in _scheduleGroups) {
      for (final day in _listValue(group['days'])) {
        final dayData = _mapValue(day);
        for (final classData in _listValue(dayData['classes'])) {
          final classMap = _mapValue(classData);
          final weeks = _mapValue(classMap['weeks']);

          for (final weekType in ['even', 'odd']) {
            final lesson = _mapValue(weeks[weekType]);
            final teacher = _nullableMapValue(lesson['teacher']);
            if (teacher == null) continue;

            final fullname = _teacherName(teacher);
            if (fullname.isNotEmpty) teacherSet.add(fullname);
          }
        }
      }
    }

    final sorted = teacherSet.toList()..sort();
    return List.generate(
      sorted.length,
      (i) => {'id': i + 1, 'fullname': sorted[i]},
    );
  }

  static List<Map<String, dynamic>> getScheduleForGroup(int groupId) {
    final group = _scheduleGroups.cast<Map<String, dynamic>?>().firstWhere(
      (group) => group != null && _groupInfo(group)['id'] == groupId,
      orElse: () => null,
    );
    if (group == null) return [];

    return _scheduleFromGroup(group);
  }

  static List<Map<String, dynamic>> getScheduleForTeacher(String teacherName) {
    final result = <Map<String, dynamic>>[];
    final normalizedTeacherName = _normalizeSearchText(teacherName);

    for (final group in _scheduleGroups) {
      final schedule = _scheduleFromGroup(group);
      result.addAll(
        schedule.where(
          (lesson) => _normalizeSearchText(
            lesson['teacher'].toString(),
          ).contains(normalizedTeacherName),
        ),
      );
    }

    return result;
  }

  static List<Map<String, dynamic>> _scheduleFromGroup(
    Map<String, dynamic> group,
  ) {
    final result = <Map<String, dynamic>>[];
    final groupTitle = _groupInfo(group)['title']?.toString() ?? '';

    for (final day in _listValue(group['days'])) {
      final dayData = _mapValue(day);
      final dayName = dayData['day'];

      for (final classData in _listValue(dayData['classes'])) {
        final classMap = _mapValue(classData);
        final classInfo = _mapValue(classMap['class']);
        final period = classInfo['id'];
        final weeks = _mapValue(classMap['weeks']);

        for (final weekType in ['even', 'odd']) {
          final lesson = _mapValue(weeks[weekType]);
          if (lesson.isEmpty) continue;

          final teacher = _nullableMapValue(lesson['teacher']);
          result.add({
            'day': dayName,
            'period': period,
            'evenodd': weekType.toUpperCase(),
            'subject': lesson['subjectForSite'] ?? 'Unknown',
            'teacher': teacher == null ? 'Unknown' : _teacherName(teacher),
            'group': groupTitle,
            'room': _mapValue(lesson['room'])['name'] ?? 'Unknown',
            'type': lesson['lessonType'] ?? 'UNKNOWN',
          });
        }
      }
    }

    return result;
  }

  static List<Map<String, dynamic>> get _groups {
    final groups = _cachedData?['groups'];
    if (groups is! List) return [];
    return groups.whereType<Map<String, dynamic>>().toList();
  }

  static List<Map<String, dynamic>> get _scheduleGroups {
    final groups = _cachedData?['scheduleGroups'];
    if (groups is! List) return [];
    return groups.whereType<Map<String, dynamic>>().toList();
  }

  static List<dynamic> _extractGroups(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      for (final key in ['semester_groups', 'groups', 'semester', 'data']) {
        final value = raw[key];
        if (value is List) return value;
        if (value is Map<String, dynamic>) {
          final nestedSemesterGroups = value['semester_groups'];
          if (nestedSemesterGroups is List) return nestedSemesterGroups;
          final nestedGroups = value['groups'];
          if (nestedGroups is List) return nestedGroups;
        }
      }
    }

    throw const FormatException(
      'Schedule API response does not contain a groups list',
    );
  }

  static List<dynamic> _extractScheduleGroups(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      for (final key in ['schedule', 'schedules', 'data']) {
        final value = raw[key];
        if (_looksLikeScheduleList(value)) return value as List;
        if (value is Map<String, dynamic>) {
          final nestedSchedule = value['schedule'];
          if (_looksLikeScheduleList(nestedSchedule)) {
            return nestedSchedule as List;
          }

          final nestedSchedules = value['schedules'];
          if (_looksLikeScheduleList(nestedSchedules)) {
            return nestedSchedules as List;
          }
        }
      }

      if (_looksLikeScheduleList(raw['semester_groups'])) {
        return raw['semester_groups'] as List;
      }
    }

    throw const FormatException(
      'Schedule API response does not contain a schedule list',
    );
  }

  static bool _looksLikeScheduleList(dynamic value) {
    if (value is! List) return false;
    return value.any((item) {
      final map = _nullableMapValue(item);
      return map != null && map['days'] is List;
    });
  }

  static Map<String, dynamic> _groupInfo(Map<String, dynamic> groupData) {
    final group = groupData['group'];
    return group is Map<String, dynamic> ? group : groupData;
  }

  static List<dynamic> _listValue(dynamic value) {
    return value is List ? value : const [];
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  static Map<String, dynamic>? _nullableMapValue(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static String _teacherName(Map<String, dynamic> teacher) {
    return [teacher['surname'], teacher['name'], teacher['patronymic']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
  }

  static String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('’', "'")
        .trim();
  }
}

Future<void> main() async {
  final env = DotEnv()..load();

  // PostgreSQL
  _db = PostgreSQLConnection(
    env['PG_HOST']!,
    int.parse(env['PG_PORT'] ?? '5432'),
    env['PG_DB']!,
    username: env['PG_USER'],
    password: env['PG_PASSWORD']?.trim(),
  );
  await _db.open();
  print('Connected to PostgreSQL');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      email      TEXT PRIMARY KEY,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS alarm_settings (
      user_email     TEXT PRIMARY KEY REFERENCES users(email) ON DELETE CASCADE,
      alarm_enabled  BOOLEAN NOT NULL DEFAULT false,
      prep_minutes   INTEGER NOT NULL DEFAULT 30,
      buffer_minutes INTEGER NOT NULL DEFAULT 10,
      updated_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  ''');

  // Schedule data
  ScheduleData.configure(semesterId: env['SEMESTER_ID'] ?? '57');

  try {
    await ScheduleData.fetchScheduleData();
    print('Fetched schedule data from API (semesterId=${env['SEMESTER_ID'] ?? '57'})');
  } catch (e) {
    print('Failed to fetch schedule data: $e');
    exit(1);
  }

  final app = Router();

  // --- User endpoints ---

  app.post('/users', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final email = body['email'] as String?;
      final alarmEnabled = body['alarm_enabled'] as bool? ?? false;
      final prepMinutes = body['prep_minutes'] as int? ?? 30;
      final bufferMinutes = body['buffer_minutes'] as int? ?? 10;

      if (email == null || email.isEmpty) {
        return Response.badRequest(body: 'Missing email');
      }

      await _db.execute(
        'INSERT INTO users (email) VALUES (@email) ON CONFLICT (email) DO NOTHING',
        substitutionValues: {'email': email},
      );
      await _db.execute(
        '''INSERT INTO alarm_settings (user_email, alarm_enabled, prep_minutes, buffer_minutes)
           VALUES (@email, @alarm, @prep, @buffer)
           ON CONFLICT (user_email) DO UPDATE
             SET alarm_enabled  = @alarm,
                 prep_minutes   = @prep,
                 buffer_minutes = @buffer,
                 updated_at     = NOW()''',
        substitutionValues: {
          'email': email,
          'alarm': alarmEnabled,
          'prep': prepMinutes,
          'buffer': bufferMinutes,
        },
      );
      return Response.ok(
        jsonEncode({'ok': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Register error: $e');
    }
  });

  app.get('/users', (Request request) async {
    final email = request.url.queryParameters['email'];
    if (email == null || email.isEmpty) {
      return Response.badRequest(body: 'Missing email');
    }
    try {
      final rows = await _db.query(
        '''SELECT u.email, a.alarm_enabled, a.prep_minutes, a.buffer_minutes
           FROM users u
           LEFT JOIN alarm_settings a ON a.user_email = u.email
           WHERE u.email = @email''',
        substitutionValues: {'email': email},
      );
      if (rows.isEmpty) return Response.notFound('User not found');
      final row = rows.first;
      return Response.ok(
        jsonEncode({
          'email': row[0],
          'alarm_enabled': row[1] ?? false,
          'prep_minutes': row[2] ?? 30,
          'buffer_minutes': row[3] ?? 10,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Get user error: $e');
    }
  });

  app.put('/users', (Request request) async {
    final email = request.url.queryParameters['email'];
    if (email == null || email.isEmpty) {
      return Response.badRequest(body: 'Missing email');
    }
    try {
      final body = jsonDecode(await request.readAsString());
      final alarmEnabled = body['alarm_enabled'] as bool? ?? false;
      final prepMinutes = body['prep_minutes'] as int? ?? 30;
      final bufferMinutes = body['buffer_minutes'] as int? ?? 10;

      final affected = await _db.execute(
        '''UPDATE alarm_settings
           SET alarm_enabled  = @alarm,
               prep_minutes   = @prep,
               buffer_minutes = @buffer,
               updated_at     = NOW()
           WHERE user_email = @email''',
        substitutionValues: {
          'email': email,
          'alarm': alarmEnabled,
          'prep': prepMinutes,
          'buffer': bufferMinutes,
        },
      );
      if (affected == 0) return Response.notFound('User not found');
      return Response.ok(
        jsonEncode({'ok': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Update user error: $e');
    }
  });

  // --- Schedule endpoints ---

  app.get('/groups', (Request request) async {
    try {
      await ScheduleData.fetchScheduleData();
      return Response.ok(
        jsonEncode(ScheduleData.getGroups()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error loading groups: $e');
    }
  });

  app.get('/teachers', (Request request) async {
    try {
      await ScheduleData.fetchScheduleData();
      return Response.ok(
        jsonEncode(ScheduleData.getTeachers()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error loading teachers: $e');
    }
  });

  app.get('/schedule', (Request request) async {
    final groupIdStr = request.url.queryParameters['groupId'];
    if (groupIdStr == null) {
      return Response.badRequest(body: 'Missing groupId');
    }

    final groupId = int.tryParse(groupIdStr);
    if (groupId == null) {
      return Response.badRequest(body: 'Invalid groupId');
    }

    try {
      await ScheduleData.fetchScheduleData();
      return Response.ok(
        jsonEncode(ScheduleData.getScheduleForGroup(groupId)),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Schedule error: $e');
      print(stack);
      return Response.internalServerError(body: 'Schedule error: $e');
    }
  });

  app.get('/schedule_teacher', (Request request) async {
    final teacherName = request.url.queryParameters['teacher'];
    if (teacherName == null || teacherName.isEmpty) {
      return Response.badRequest(body: 'Missing teacher name');
    }

    try {
      await ScheduleData.fetchScheduleData();
      return Response.ok(
        jsonEncode(ScheduleData.getScheduleForTeacher(teacherName)),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Teacher schedule error: $e');
      print(stack);
      return Response.internalServerError(body: 'Teacher schedule error: $e');
    }
  });

  // --- Route endpoint ---

  final _routesApiKey = env['GOOGLE_ROUTES_API_KEY'] ?? '';

  // --- Places Autocomplete (proxy) ---

  app.post('/autocomplete', (Request request) async {
    if (_routesApiKey.isEmpty) {
      return Response.internalServerError(body: 'API key not configured');
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final input = body['input'] as String?;
      final sessionToken = body['sessionToken'] as String?;

      if (input == null || input.trim().isEmpty) {
        return Response.badRequest(body: 'Missing input');
      }

      final reqBody = <String, dynamic>{
        'input': input.trim(),
        if (sessionToken != null) 'sessionToken': sessionToken,
        'regionCode': 'UA',
        'locationBias': {
          'circle': {
            'center': {'latitude': 48.293, 'longitude': 25.935},
            'radius': 40000.0,
          },
        },
      };

      final response = await http
          .post(
            Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _routesApiKey,
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.text,suggestions.placePrediction.placeId',
            },
            body: jsonEncode(reqBody),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        print('[autocomplete] Google error ${response.statusCode}: ${response.body}');
        return Response(503, body: 'Google error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List? ?? [])
          .map((s) {
            final pred = s['placePrediction'] as Map<String, dynamic>?;
            if (pred == null) return null;
            final textMap = pred['text'] as Map<String, dynamic>?;
            final text = textMap?['text'] as String? ?? '';
            final placeId = pred['placeId'] as String? ?? '';
            if (text.isEmpty || placeId.isEmpty) return null;
            return {'placeId': placeId, 'text': text};
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      return Response.ok(
        jsonEncode(suggestions),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[autocomplete] Error: $e');
      return Response.internalServerError(body: 'Autocomplete error: $e');
    }
  });

  // --- Place Details (proxy) ---

  app.get('/place', (Request request) async {
    final params = request.url.queryParameters;
    final placeId = params['placeId'];
    final sessionToken = params['sessionToken'];

    if (placeId == null || placeId.isEmpty) {
      return Response.badRequest(body: 'Missing placeId');
    }
    if (_routesApiKey.isEmpty) {
      return Response.internalServerError(body: 'API key not configured');
    }

    try {
      final qp = sessionToken != null ? {'sessionToken': sessionToken} : null;
      final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId')
          .replace(queryParameters: qp);

      final response = await http.get(uri, headers: {
        'X-Goog-Api-Key': _routesApiKey,
        'X-Goog-FieldMask': 'location,formattedAddress,displayName',
      }).timeout(const Duration(seconds: 8));

      final shortId = placeId.length > 12 ? '${placeId.substring(0, 12)}…' : placeId;
      print('[${DateTime.now().toIso8601String()}] /place id=$shortId → ${response.statusCode}');

      if (response.statusCode != 200) {
        return Response(503, body: 'Google error: ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) return Response(503, body: 'No location in response');

      final lat = location['latitude'] as num?;
      final lng = location['longitude'] as num?;
      if (lat == null || lng == null) return Response(503, body: 'Missing lat/lng');

      final address = (data['formattedAddress'] as String?) ??
          ((data['displayName'] as Map?)?['text'] as String?) ??
          '';

      return Response.ok(
        jsonEncode({'lat': lat.toDouble(), 'lng': lng.toDouble(), 'address': address}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[place] Error: $e');
      return Response.internalServerError(body: 'Place details error: $e');
    }
  });

  // --- Route endpoint ---

  app.get('/route', (Request request) async {
    final params = request.url.queryParameters;
    final latStr  = params['lat'];
    final lngStr  = params['lng'];
    final address = params['address']; // альтернатива lat/lng
    final mode    = params['mode'] ?? 'walking';

    if (_routesApiKey.isEmpty) {
      return Response.internalServerError(
          body: 'GOOGLE_ROUTES_API_KEY not configured');
    }

    // Будуємо origin: або за адресою, або за координатами
    Map<String, dynamic> origin;
    if (address != null && address.trim().isNotEmpty) {
      origin = {'address': address.trim()};
    } else if (latStr != null && lngStr != null) {
      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);
      if (lat == null || lng == null) {
        return Response.badRequest(body: 'Invalid lat/lng');
      }
      origin = {
        'location': {
          'latLng': {'latitude': lat, 'longitude': lng}
        }
      };
    } else {
      return Response.badRequest(body: 'Provide address or lat+lng');
    }

    // Destination: з параметрів або дефолт — ФМІ ЧДНУ
    final destLat = double.tryParse(params['destLat'] ?? '') ?? 48.2932673;
    final destLng = double.tryParse(params['destLng'] ?? '') ?? 25.929342;

    final travelMode = switch (mode) {
      'car'     => 'DRIVE',
      'transit' => 'TRANSIT',
      _         => 'WALK',
    };

    final body = <String, dynamic>{
      'origin': origin,
      'destination': {
        'location': {
          'latLng': {'latitude': destLat, 'longitude': destLng}
        }
      },
      'travelMode': travelMode,
    };

    if (travelMode == 'DRIVE') {
      body['routingPreference'] = 'TRAFFIC_AWARE';
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://routes.googleapis.com/directions/v2:computeRoutes'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _routesApiKey,
              'X-Goog-FieldMask':
                  'routes.duration,routes.staticDuration,routes.distanceMeters',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final ts = DateTime.now().toIso8601String();

      if (response.statusCode == 401 || response.statusCode == 403) {
        print('[$ts] /route → Google auth error ${response.statusCode}: ${response.body}');
        return Response(503, body: 'Google auth error: ${response.statusCode}');
      }
      if (response.statusCode == 429) {
        print('[$ts] /route → Google quota exceeded');
        return Response(503, body: 'Quota exceeded');
      }
      if (response.statusCode != 200) {
        print('[$ts] /route → Google error ${response.statusCode}: ${response.body}');
        return Response(503, body: 'Google error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return Response(503, body: 'No routes returned');
      }

      final route = routes[0] as Map<String, dynamic>;

      final durationSec = _parseSeconds(route['duration'] as String?);
      final staticSec = _parseSeconds(route['staticDuration'] as String?);
      final meters = route['distanceMeters'] as int? ?? 0;
      final minutes = (durationSec / 60).ceil();
      final staticMinutes = (staticSec / 60).ceil();

      final originLabel = address != null ? 'addr' : 'gps';
      print('[$ts] /route mode=$mode origin=$originLabel → ${minutes}хв (без трафіку: ${staticMinutes}хв, ${meters}м)');

      return Response.ok(
        jsonEncode({
          'minutes': minutes,
          'staticMinutes': staticMinutes,
          'meters': meters,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on http.ClientException catch (e) {
      print('[${DateTime.now().toIso8601String()}] /route → network error: $e');
      return Response(503, body: 'Network error: $e');
    } catch (e) {
      print('[${DateTime.now().toIso8601String()}] /route → unexpected error: $e');
      return Response.internalServerError(body: 'Route error: $e');
    }
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(app);
  final server = await serve(handler, InternetAddress.anyIPv4, 8000);
  print('Server running on http://0.0.0.0:${server.port}');
}
