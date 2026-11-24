import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'db_service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'; // already used elsewhere if needed

// Removed duplicate import of db_service and added path_provider import.
// Simplify generateAndOpenReportPdf for Windows only – remove web-specific code.




class ApiService {
  // Production: Render backend URL. Locally: localhost:8000
  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );
  static String? _token;
  static String? _userRole;
  static String? _userName;

  static String get baseUrl => _baseUrl;
  static String? get token => _token;
  static String? get userRole => _userRole;
  static String? get userName => _userName;

  // Initialize and load saved authentication state
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? 'http://localhost:8000/api';
    _token = prefs.getString('auth_token');
    _userRole = prefs.getString('user_role');
    _userName = prefs.getString('user_name');
    
    // Auto-authenticate if no token is found
    if (_token == null || _token!.isEmpty) {
      await ensureAuthenticated();
    }
  }

  static Future<void> ensureAuthenticated() async {
    if (_token != null && _token!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      _userRole = prefs.getString('user_role');
      _userName = prefs.getString('user_name');
      return;
    }
    await login('doctor', 'password');
  }

  static Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
  }

  // Request headers
  static Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ──────────────────────────────────────────────────────────────
  // Authentication
  // ──────────────────────────────────────────────────────────────
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login-json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _userRole = data['role'];
        _userName = data['full_name'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_role', _userRole!);
        await prefs.setString('user_name', _userName!);
        // Save user locally in SQLite
        await DBService.upsertUser(
          username: username,
          password: password,
          token: _token,
          role: _userRole,
          name: _userName,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    _token = null;
    _userRole = null;
    _userName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
  }

  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  // ──────────────────────────────────────────────────────────────
  // Dashboard
  // ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      await ensureAuthenticated();
      var response = await http.get(
        Uri.parse('$_baseUrl/dashboard/stats'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.get(
          Uri.parse('$_baseUrl/dashboard/stats'),
          headers: _headers(),
        );
      }
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('Error loading stats: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // Patient APIs
  // ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> searchPatients([String? query]) async {
    try {
      await ensureAuthenticated();
      String url = '$_baseUrl/patients';
      if (query != null && query.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(query)}';
      }
      var response = await http.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.get(Uri.parse(url), headers: _headers());
      }
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('Search patients error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> registerPatient({
    required String name,
    required int age,
    required String gender,
    String? phone,
    String? village,
    double diabetesDuration = 0.0,
    bool hasHypertension = false,
    bool hasPrevEyeIssues = false,
    String? prevEyeNotes,
  }) async {
    try {
      await ensureAuthenticated();
      final body = jsonEncode({
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone,
        'village': village,
        'diabetes_duration': diabetesDuration,
        'has_hypertension': hasHypertension,
        'has_prev_eye_issues': hasPrevEyeIssues,
        'prev_eye_notes': prevEyeNotes,
      });
      var response = await http.post(
        Uri.parse('$_baseUrl/patients'),
        headers: _headers(),
        body: body,
      );
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.post(
          Uri.parse('$_baseUrl/patients'),
          headers: _headers(),
          body: body,
        );
      }
      if (response.statusCode == 201) return jsonDecode(response.body);
      print('Register patient failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      print('Register patient error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPatientDetails(int patientId) async {
    try {
      await ensureAuthenticated();
      var response = await http.get(
        Uri.parse('$_baseUrl/patients/$patientId'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.get(
          Uri.parse('$_baseUrl/patients/$patientId'),
          headers: _headers(),
        );
      }
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('Patient details error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // Visit APIs
  // ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> createVisit(
    int patientId, {
    String? notes,
    String? captureNotes,
  }) async {
    try {
      await ensureAuthenticated();
      final body = jsonEncode({
        'patient_id': patientId,
        'notes': notes,
        'capture_notes': captureNotes,
      });
      var response = await http.post(
        Uri.parse('$_baseUrl/visits'),
        headers: _headers(),
        body: body,
      );
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.post(
          Uri.parse('$_baseUrl/visits'),
          headers: _headers(),
          body: body,
        );
      }
      if (response.statusCode == 201) return jsonDecode(response.body);
      print('Create visit failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      print('Create visit error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> uploadRetinalImages({
    required int visitId,
    required XFile leftEyeFile,
    required XFile rightEyeFile,
  }) async {
    try {
      await ensureAuthenticated();
      String contentTypeFor(XFile file) {
        final lowerName = file.name.toLowerCase();
        if (lowerName.endsWith('.png')) return 'png';
        if (lowerName.endsWith('.webp')) return 'webp';
        if (lowerName.endsWith('.avif')) return 'avif';
        return 'jpeg';
      }

      final leftBytes = await leftEyeFile.readAsBytes();
      final rightBytes = await rightEyeFile.readAsBytes();

      Future<http.Response> sendUploadReq() async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/visits/$visitId/upload-images'),
        );
        request.headers.addAll({
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        });
        request.files.add(http.MultipartFile.fromBytes(
          'left_eye',
          leftBytes,
          filename: leftEyeFile.name,
          contentType: MediaType('image', contentTypeFor(leftEyeFile)),
        ));
        request.files.add(http.MultipartFile.fromBytes(
          'right_eye',
          rightBytes,
          filename: rightEyeFile.name,
          contentType: MediaType('image', contentTypeFor(rightEyeFile)),
        ));
        final streamedResponse = await request.send();
        return await http.Response.fromStream(streamedResponse);
      }

      var response = await sendUploadReq();
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await sendUploadReq();
      }

      if (response.statusCode == 200) return jsonDecode(response.body);
      print('Upload images failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      print('Upload images error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> runAIPrediction(
    int visitId, {
    String? doctorNotes,
    String? captureNotes,
  }) async {
    try {
      await ensureAuthenticated();
      String body = '';
      if (doctorNotes != null) {
        body += 'doctor_notes=${Uri.encodeQueryComponent(doctorNotes)}';
      }
      if (captureNotes != null) {
        if (body.isNotEmpty) body += '&';
        body += 'capture_notes=${Uri.encodeQueryComponent(captureNotes)}';
      }

      var response = await http.post(
        Uri.parse('$_baseUrl/visits/$visitId/analyze'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.isNotEmpty ? body : null,
      );
      if (response.statusCode == 401) {
        await login('doctor', 'password');
        response = await http.post(
          Uri.parse('$_baseUrl/visits/$visitId/analyze'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body.isNotEmpty ? body : null,
        );
      }
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('AI Prediction error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // Report & Heatmap
  // ──────────────────────────────────────────────────────────────
  static String getHeatmapUrl(int visitId, String eye, [String disease = 'glaucoma']) {
    return '$_baseUrl/visits/$visitId/heatmap/${eye.toLowerCase()}?disease=${disease.toLowerCase()}';
  }

  static Map<String, String> getAuthHeaders() {
    return {'Authorization': 'Bearer $_token'};
  }

  static Future<bool> generateAndOpenReportPdf(int visitId) async {
  try {
    await ensureAuthenticated();
    var response = await http.get(
      Uri.parse('$_baseUrl/visits/$visitId/report'),
      headers: _headers(),
    );
    if (response.statusCode == 401) {
      await login('doctor', 'password');
      response = await http.get(
        Uri.parse('$_baseUrl/visits/$visitId/report'),
        headers: _headers(),
      );
    }
    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/glaucoma_screening_report_visit_$visitId.pdf';
      final file = io.File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await OpenFile.open(filePath);
      return true;
    }
  } catch (e) {
    print('PDF generation/open error: $e');
  }
  return false;
}

}
