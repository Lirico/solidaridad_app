import 'dart:async';

import 'package:flutter/services.dart';

/// Dart facade for the Android Verifone PaymentSDK bridge.
///
/// Channel contract (Android):
/// - methods: `initialize`, `tearDown`, `getStatus`, `getDeviceInfo`,
///   `readMsr`, `printHtml`
/// - events: status maps from `CommerceListenerAdapter.handleStatus`
class PsdkBridge {
  PsdkBridge({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methods =
          methodChannel ??
          const MethodChannel('com.solidaridad.poc_verifone/psdk'),
      _events =
          eventChannel ??
          const EventChannel('com.solidaridad.poc_verifone/psdk_events');

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<Map<String, dynamic>>? _statusStream;

  /// Live status / lifecycle events from the native SDK.
  Stream<Map<String, dynamic>> get statusEvents {
    return _statusStream ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'raw': event};
    });
  }

  /// Creates the native [PaymentSdk] and starts async initialize.
  /// Listen to [statusEvents] for `success == true` / `sdiReady`.
  Future<Map<String, dynamic>> initialize() async {
    final result = await _methods.invokeMethod<dynamic>('initialize');
    return _asStringKeyMap(result);
  }

  Future<Map<String, dynamic>> tearDown() async {
    final result = await _methods.invokeMethod<dynamic>('tearDown');
    return _asStringKeyMap(result);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final result = await _methods.invokeMethod<dynamic>('getStatus');
    return _asStringKeyMap(result);
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _methods.invokeMethod<dynamic>('getDeviceInfo');
    return _asStringKeyMap(result);
  }

  /// Waits for a magstripe swipe (blocks up to [timeoutSec]).
  ///
  /// Returns unmasked POC fields under `msr` (direct SDK response) and `tags`
  /// (`fetchTxnTags`, often clearer when the terminal obfuscates `msr`).
  Future<Map<String, dynamic>> readMsr({int timeoutSec = 30}) async {
    final result = await _methods.invokeMethod<dynamic>(
      'readMsr',
      <String, dynamic>{'timeoutSec': timeoutSec},
    );
    return _asStringKeyMap(result);
  }

  /// Prints [html] on the terminal thermal printer (`SdiPrinter.printHTML`).
  /// Requires native [initialize] with `sdiReady`.
  Future<Map<String, dynamic>> printHtml(
    String html, {
    bool landscape = false,
  }) async {
    final result = await _methods.invokeMethod<dynamic>(
      'printHtml',
      <String, dynamic>{'html': html, 'landscape': landscape},
    );
    return _asStringKeyMap(result);
  }

  Map<String, dynamic> _asStringKeyMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{'ok': false, 'message': 'unexpected: $value'};
  }
}
