/// Identidad de la terminal que se envía al backend.
///
/// Reúne los tres identificadores que el tech leader quiere recibir:
/// - [installationId]: código de negocio de 8 caracteres (lo carga el procesador).
/// - [serialNumber]: matrícula de fábrica del equipo (lo lee el PSDK).
/// - [logicalDeviceId]: id asignado por el sistema de gestión de Verifone (PSDK).
class DeviceIdentity {
  const DeviceIdentity({
    required this.installationId,
    this.serialNumber,
    this.logicalDeviceId,
  });

  final String installationId;
  final String? serialNumber;
  final String? logicalDeviceId;

  bool get hasHardwareInfo => serialNumber != null && logicalDeviceId != null;
}