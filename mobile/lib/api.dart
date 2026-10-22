import 'dart:convert';
// import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? code;

  ApiException(this.message, [this.code]);

  @override
  String toString() => message;
}

class Api {
  static const String _custom =
      String.fromEnvironment('API_URL');

  static String get base => _custom.isNotEmpty
      ? _custom
      : (kIsWeb
          ? 'http://localhost:8000/api'
          : 'http://192.168.43.122:8000/api');

  static late SharedPreferences _p;

  static String? token;
  static Map<String, dynamic>? user;

  // ============================================================
  // INITIALISATION
  // ============================================================

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();

    token = _p.getString('token');

    final savedUser = _p.getString('user');

    if (savedUser != null && savedUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedUser);

        if (decoded is Map) {
          user = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        user = null;
      }
    }
  }

  // ============================================================
  // USER
  // ============================================================

  static String get role {
    return user?['role']?.toString() ?? '';
  }

  static bool get isAdmin {
    return role == 'admin';
  }

  static bool get isTechnicien {
    return role == 'technicien';
  }

  static bool get canWrite {
    return isAdmin || isTechnicien;
  }

  static Future<void> saveUser() async {
    if (user == null) {
      await _p.remove('user');
      return;
    }

    await _p.setString(
      'user',
      jsonEncode(user),
    );
  }

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  static Map<String, String> get authHeaders => {
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  // ============================================================
  // RESPONSE
  // ============================================================

  static dynamic _decode(http.Response response) {
    dynamic body;

    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 400) {
      var message = 'Erreur ${response.statusCode}';

      if (body is Map) {
        final messages = <String>[];

        body.forEach((key, value) {
          if (value is List) {
            messages.add(
              '$key : ${value.join(', ')}',
            );
          } else if (value is Map) {
            messages.add(
              '$key : ${value.toString()}',
            );
          } else {
            messages.add(
              '$key : ${value.toString()}',
            );
          }
        });

        if (messages.isNotEmpty) {
          message = messages.join('\n');
        }
      } else if (body is String && body.isNotEmpty) {
        message = body;
      }

      throw ApiException(
        message,
        response.statusCode,
      );
    }

    return body;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<void> login(
    String username,
    String password,
  ) async {
    final response = await http
        .post(
          Uri.parse('$base/auth/login/'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final body = _decode(response);

    if (body is! Map) {
      throw ApiException(
        'Réponse invalide du serveur.',
      );
    }

    token = body['access']?.toString();

    if (body['user'] is Map) {
      user = Map<String, dynamic>.from(
        body['user'],
      );
    } else {
      user = null;
    }

    if (token == null || token!.isEmpty) {
      throw ApiException(
        'Token d’authentification absent.',
      );
    }

    await _p.setString(
      'token',
      token!,
    );

    await saveUser();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    token = null;
    user = null;

    await _p.remove('token');
    await _p.remove('user');
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<dynamic> get(
    String path, {
    bool cache = true,
  }) async {
    final key = 'cache:$path';

    try {
      final response = await http
          .get(
            Uri.parse('$base$path'),
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final body = _decode(response);

      if (cache) {
        try {
          await _p.setString(
            key,
            jsonEncode(body),
          );
        } catch (_) {}
      }

      return body;
    } on ApiException {
      rethrow;
    } catch (_) {
      if (cache) {
        final cached = _p.getString(key);

        if (cached != null && cached.isNotEmpty) {
          try {
            return jsonDecode(cached);
          } catch (_) {}
        }
      }

      throw ApiException(
        'Impossible de contacter le serveur.',
      );
    }
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<dynamic> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await http
        .post(
          Uri.parse('$base$path'),
          headers: headers,
          body: jsonEncode(
            body ?? {},
          ),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    return _decode(response);
  }

  // ============================================================
  // PATCH JSON
  // ============================================================

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$base$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final result = _decode(response);

    if (path == '/auth/profile/' &&
        result is Map) {
      user = Map<String, dynamic>.from(result);
      await saveUser();
    }

    return result;
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<dynamic> delete(
    String path,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$base$path'),
          headers: headers,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final result = _decode(response);

    return result ?? true;
  }

  // ============================================================
  // GET BYTES
  // ============================================================

  static Future<Uint8List> getBytes(
    String path,
  ) async {
    final response = await http
        .get(
          Uri.parse('$base$path'),
          headers: authHeaders,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode >= 400) {
      throw ApiException(
        'Erreur ${response.statusCode}',
        response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  // ============================================================
  // POST MULTIPART
  // ============================================================

  static Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> payload,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$base$path'),
    );

    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer $token';
    }

    payload.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    if (photoBytes != null &&
        photoBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename:
              photoName ?? 'profile.jpg',
        ),
      );
    }

    final streamedResponse =
        await request.send().timeout(
              const Duration(seconds: 30),
            );

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    return _decode(response);
  }

  // ============================================================
  // PATCH MULTIPART
  // ============================================================

  static Future<dynamic> patchMultipart(
    String path, {
    required Map<String, dynamic> payload,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$base$path'),
    );

    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer $token';
    }

    // Champs normaux
    payload.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // Photo
    if (photoBytes != null &&
        photoBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename:
              photoName ?? 'profile.jpg',
        ),
      );
    }

    final streamedResponse =
        await request.send().timeout(
              const Duration(seconds: 30),
            );

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    final result = _decode(response);

    if (path == '/auth/profile/' &&
        result is Map) {
      user = Map<String, dynamic>.from(result);
      await saveUser();
    }

    return result;
  }

  // ============================================================
  // FILE URL
  // ============================================================

  static String fileUrl(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(value);

    if (uri != null && uri.hasScheme) {
      return value;
    }

    final baseUri = Uri.parse(base);

    final root =
        '${baseUri.scheme}://${baseUri.authority}';

    if (value.startsWith('/')) {
      return '$root$value';
    }

    return '$root/$value';
  }

  // ============================================================
  // OFFLINE QUEUE
  // ============================================================

  static int get pending {
    return (_p.getStringList('queue') ?? [])
        .length;
  }

  static Future<dynamic> postQueued(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await post(
        path,
        body,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      final queue =
          _p.getStringList('queue') ?? [];

      queue.add(
        jsonEncode({
          'path': path,
          'body': body,
        }),
      );

      await _p.setStringList(
        'queue',
        queue,
      );

      return null;
    }
  }

  // ============================================================
  // SYNC
  // ============================================================

  static Future<int> sync() async {
    final queue =
        _p.getStringList('queue') ?? [];

    final remaining = <String>[];
    var done = 0;

    for (final item in queue) {
      try {
        final data = jsonDecode(item);

        await post(
          data['path'],
          Map<String, dynamic>.from(
            data['body'],
          ),
        );

        done++;
      } on ApiException {
        done++;
      } catch (_) {
        remaining.add(item);
      }
    }

    await _p.setStringList(
      'queue',
      remaining,
    );

    return done;
  }
}