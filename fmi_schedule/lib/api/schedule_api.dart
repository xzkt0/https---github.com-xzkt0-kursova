import 'dart:convert';
import 'package:http/http.dart' as http;

class ScheduleApi {
  static const String _baseUrl = 'http://172.20.10.3:8000';
  // Локальний сервер

  static Future<List<Map<String, dynamic>>> fetchGroupsWithId() async {
    final response = await http.get(Uri.parse('$_baseUrl/groups'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch groups');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTeachersWithId() async {
    final response = await http.get(Uri.parse('$_baseUrl/teachers'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch teachers');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSchedule(int groupId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule?groupId=$groupId'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch schedule');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchScheduleByTeacher(
      String teacherName) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule_teacher?teacher=$teacherName'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch teacher schedule');
    }
  }
}
