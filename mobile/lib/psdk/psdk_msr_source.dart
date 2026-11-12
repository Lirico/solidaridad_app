import 'psdk_msr_lab.dart' if (dart.vm.product) 'psdk_msr_unavailable.dart';

const String releaseMsrMockError =
    'USE_MSR_MOCK no está disponible en un APK de release.';

/// El mock solo corre fuera de release y con el define prendido.
///
/// En release [readLabMsr] es el archivo sin datos de tarjeta. Un define
/// prendido en ese APK lanza [StateError] y no devuelve el fixture.
bool labMsrEnabled({required bool useMock, required bool releaseMode}) {
  if (!useMock) return false;
  if (releaseMode) throw StateError(releaseMsrMockError);
  return true;
}

Map<String, dynamic> labReadMsr({required int timeoutSec}) {
  return readLabMsr(timeoutSec: timeoutSec);
}
