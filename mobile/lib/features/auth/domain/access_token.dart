import 'dart:convert';

/// Vigencia local de un access token, sin validar la firma.
///
/// La API envía `exp` a 90 días. [accessTokenStatus] trata vencido a un token
/// cuyo `exp` ya llegó. Si el claim no viene, la sesión sigue vigente.
enum AccessTokenStatus { valid, expired, unreadable }

AccessTokenStatus accessTokenStatus(String token, {DateTime? now}) {
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    return AccessTokenStatus.unreadable;
  }

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return AccessTokenStatus.unreadable;
    if (!payload.containsKey('exp')) return AccessTokenStatus.valid;

    final exp = payload['exp'];
    if (exp is! num) return AccessTokenStatus.unreadable;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    final current = (now ?? DateTime.now()).toUtc();
    if (!current.isBefore(expiresAt)) return AccessTokenStatus.expired;
    return AccessTokenStatus.valid;
  } catch (_) {
    return AccessTokenStatus.unreadable;
  }
}
