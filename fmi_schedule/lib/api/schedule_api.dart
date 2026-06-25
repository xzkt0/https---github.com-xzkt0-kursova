import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ScheduleApi {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get _baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://172.20.10.2:8000';
  }

  static Future<List<Map<String, dynamic>>> fetchGroupsWithId() async {
    final response = await http.get(Uri.parse('$_baseUrl/groups'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch groups: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchTeachersWithId() async {
    final response = await http.get(Uri.parse('$_baseUrl/teachers'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch teachers: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchSchedule(int groupId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule').replace(
        queryParameters: {'groupId': groupId.toString()},
      ),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch schedule: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchScheduleByTeacher(
    String teacherName,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule_teacher').replace(
        queryParameters: {'teacher': teacherName},
      ),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch teacher schedule: ${response.statusCode}');
  }
}
