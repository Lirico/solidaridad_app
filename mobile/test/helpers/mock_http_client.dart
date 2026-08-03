import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

/// A mock [http.Client] for use in tests.
class MockHttpClient extends Mock implements http.Client {}

/// Creates a successful JSON [http.Response] with the given [body] and [statusCode].
http.Response jsonResponse(String body, {int statusCode = 200}) {
  return http.Response(
    body,
    statusCode,
    headers: {HttpHeaders.contentTypeHeader: 'application/json'},
  );
}

/// Creates a JSON [http.Response] from a [Map].
http.Response jsonMapResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return jsonResponse(jsonEncode(body), statusCode: statusCode);
}

/// Creates a JSON [http.Response] from a [List].
http.Response jsonListResponse(List<dynamic> body, {int statusCode = 200}) {
  return jsonResponse(jsonEncode(body), statusCode: statusCode);
}

/// Registers a fallback for [http.Client] so mocktail can use it in matchers.
void registerHttpClientFallback() {
  registerFallbackValue(http.Client());
}
