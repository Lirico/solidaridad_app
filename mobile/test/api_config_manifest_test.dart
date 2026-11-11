import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory androidSrc;

  setUpAll(() {
    androidSrc = Directory('android/app/src');
    expect(
      androidSrc.existsSync(),
      isTrue,
      reason: 'Correr flutter test desde mobile/',
    );
  });

  String read(String relative) {
    return File('${androidSrc.path}/$relative').readAsStringSync();
  }

  test('el manifiesto principal no abre HTTP', () {
    final mainManifest = read('main/AndroidManifest.xml');

    expect(mainManifest.contains('usesCleartextTraffic'), isFalse);
  });

  test('debug y profile permiten HTTP de laboratorio', () {
    expect(
      read('debug/AndroidManifest.xml'),
      contains('android:usesCleartextTraffic="true"'),
    );
    expect(
      read('profile/AndroidManifest.xml'),
      contains('android:usesCleartextTraffic="true"'),
    );
  });

  test('release apunta a una config que prohíbe HTTP', () {
    expect(
      read('release/AndroidManifest.xml'),
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(
      read('release/res/xml/network_security_config.xml'),
      contains('cleartextTrafficPermitted="false"'),
    );
  });
}
