import '../domain/auth_model.dart';

/// Fuente local del comercio asociado a la sesión activa.
///
/// La sesión no se persiste entre reinicios de la app, por lo que este store
/// también vive solo en memoria. Se carga con la respuesta del login y luego
/// se reemplaza únicamente cuando un refresco periódico termina con éxito.
class MerchantStore {
  Merchant? _current;

  Merchant? get current => _current;

  void replace(Merchant? merchant) {
    _current = merchant;
  }

  void clear() {
    _current = null;
  }
}
