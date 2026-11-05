import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/receipt_defaults.dart';

/// Lee el perfil mock del comprobante y lo conserva en memoria.
class ReceiptDefaultsRepository {
  ReceiptDefaultsRepository({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;
  ReceiptDefaults? _cached;

  static const String assetPath = 'assets/receipt_defaults.json';

  Future<ReceiptDefaults> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final bundle = _bundle ?? rootBundle;
    final raw = await bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('receipt_defaults.json no es un objeto');
    }
    final defaults = ReceiptDefaults.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    _cached = defaults;
    return defaults;
  }
}
