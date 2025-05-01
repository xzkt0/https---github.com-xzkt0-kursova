import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> main() async {
  final env = DotEnv()..load();

  final db = PostgreSQLConnection(
    env['PG_HOST']!,
    int.parse(env['PG_PORT']!),
    env['PG_DB']!,
    username: env['PG_USER'],
    password: env['PG_PASSWORD'],
  );

  try {
    await db.open();
    print('✅ Connected to PostgreSQL');
  } catch (e) {
    print('❌ Failed to connect to DB: $e');
    exit(1);
  }

  final app = Router();

  // GET /groups (id + title)
  app.get('/groups', (Request request) async {
    try {
      final result = await db.query(
        'SELECT id, title FROM groups ORDER BY sort_order',
      );
      final groups =
          result.map((row) => {'id': row[0], 'title': row[1]}).toList();
      return Response.ok(
        jsonEncode(groups),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error loading groups: $e');
    }
  });

  // GET /schedule?groupId=...
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
      final result = await db.query(
        '''
        SELECT
          s.day_of_week,
          s.period_id,
          s.evenodd,
          sub.name AS subject,
          t.surname || ' ' || t.name || ' ' || t.patronymic AS teacher,
          r.name AS room,
          l.lessontype
        FROM lessons l
        JOIN schedules s ON s.lesson_id = l.id
        JOIN subjects sub ON l.subject_id = sub.id
        JOIN teachers t ON l.teacher_id = t.id
        JOIN rooms r ON s.room_id = r.id
        WHERE l.group_id = @groupId
        ORDER BY s.day_of_week, s.period_id
      ''',
        substitutionValues: {'groupId': groupId},
      );

      final data =
          result
              .map(
                (row) => {
                  'day': row[0], // e.g., MONDAY
                  'period': row[1], // e.g., 1..6
                  'evenodd': row[2], // EVEN / ODD
                  'subject': row[3],
                  'teacher': row[4],
                  'room': row[5],
                  'type': row[6], // e.g., LECTURE / LAB
                },
              )
              .toList();

      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ Schedule error: $e');
      print(stack);
      return Response.internalServerError(body: 'Schedule error: $e');
    }
  });

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(app);
  final server = await serve(handler, InternetAddress.anyIPv4, 8000);
  print('✅ Server running on http://0.0.0.0:${server.port}');
  // GET /schedule_teacher?teacher=...
  app.get('/schedule_teacher', (Request request) async {
    final teacherName = request.url.queryParameters['teacher'];
    if (teacherName == null || teacherName.isEmpty) {
      return Response.badRequest(body: 'Missing teacher name');
    }

    try {
      final result = await db.query(
        '''
      SELECT
        s.day_of_week,
        s.period_id,
        s.evenodd,
        sub.name AS subject,
        t.surname || ' ' || t.name || ' ' || t.patronymic AS teacher,
        r.name AS room,
        l.lessontype
      FROM lessons l
      JOIN schedules s ON s.lesson_id = l.id
      JOIN subjects sub ON l.subject_id = sub.id
      JOIN teachers t ON l.teacher_id = t.id
      JOIN rooms r ON s.room_id = r.id
      WHERE (t.surname || ' ' || t.name || ' ' || t.patronymic) ILIKE @teacherName
      ORDER BY s.day_of_week, s.period_id
      ''',
        substitutionValues: {'teacherName': '%$teacherName%'},
      );

      final data =
          result
              .map(
                (row) => {
                  'day': row[0],
                  'period': row[1],
                  'evenodd': row[2],
                  'subject': row[3],
                  'teacher': row[4],
                  'room': row[5],
                  'type': row[6],
                },
              )
              .toList();

      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ Teacher schedule error: $e');
      print(stack);
      return Response.internalServerError(body: 'Teacher schedule error: $e');
    }
  });
  // GET /schedule_teacher?teacher=...
  app.get('/schedule_teacher', (Request request) async {
    final teacherName = request.url.queryParameters['teacher'];
    if (teacherName == null || teacherName.isEmpty) {
      return Response.badRequest(body: 'Missing teacher name');
    }

    try {
      final result = await db.query(
        '''
      SELECT
        s.day_of_week,
        s.period_id,
        s.evenodd,
        sub.name AS subject,
        t.surname || ' ' || t.name || ' ' || t.patronymic AS teacher,
        r.name AS room,
        l.lessontype
      FROM lessons l
      JOIN schedules s ON s.lesson_id = l.id
      JOIN subjects sub ON l.subject_id = sub.id
      JOIN teachers t ON l.teacher_id = t.id
      JOIN rooms r ON s.room_id = r.id
      WHERE (t.surname || ' ' || t.name || ' ' || t.patronymic) ILIKE @teacherName
      ORDER BY s.day_of_week, s.period_id
      ''',
        substitutionValues: {'teacherName': '%$teacherName%'},
      );

      final data =
          result
              .map(
                (row) => {
                  'day': row[0],
                  'period': row[1],
                  'evenodd': row[2],
                  'subject': row[3],
                  'teacher': row[4],
                  'room': row[5],
                  'type': row[6],
                },
              )
              .toList();

      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ Teacher schedule error: $e');
      print(stack);
      return Response.internalServerError(body: 'Teacher schedule error: $e');
    }
  });
  // GET /teachers
  app.get('/teachers', (Request request) async {
    try {
      final result = await db.query('''
      SELECT id, surname || ' ' || name || ' ' || patronymic AS fullname
      FROM teachers
      ORDER BY surname
      ''');
      final teachers =
          result.map((row) => {'id': row[0], 'fullname': row[1]}).toList();

      return Response.ok(
        jsonEncode(teachers),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error loading teachers: $e');
    }
  });
}
