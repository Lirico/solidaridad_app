import '../domain/auth_model.dart';

/// Vista en memoria del comercio asociado a la sesión activa.
///
/// La copia que sobrevive a un reinicio está en el almacenamiento de la
/// sesión. Este store se carga al restaurarla, con la respuesta del login y
/// cuando un refresco periódico termina con éxito.
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
