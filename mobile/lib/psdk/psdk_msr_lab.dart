import 'psdk_msr_mock.dart';

/// Lectura de laboratorio. Este archivo no entra en el APK de release:
/// ahí el import condicional elige [psdk_msr_unavailable.dart].
Map<String, dynamic> readLabMsr({required int timeoutSec}) {
  return PsdkMsrMock.readMsrSuccess(timeoutSec: timeoutSec);
}
