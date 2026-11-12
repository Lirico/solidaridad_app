class User {
  final String name;
  final String email;
  final String token;

  const User({required this.name, required this.email, required this.token});
}

/// Comercio vigente de la cuenta. La API lo entrega en el login y en
/// `GET /v1/me/merchant`.
class Merchant {
  final String code;
  final String name;
  final String address;
  final String city;
  final String taxId;

  const Merchant({
    required this.code,
    required this.name,
    required this.address,
    required this.city,
    required this.taxId,
  });

  static Merchant? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code'];
    final name = raw['name'];
    final address = raw['address'];
    final city = raw['city'];
    final taxId = raw['tax_id'];
    if (code is! String ||
        name is! String ||
        address is! String ||
        city is! String ||
        taxId is! String) {
      return null;
    }
    return Merchant(
      code: code,
      name: name,
      address: address,
      city: city,
      taxId: taxId,
    );
  }

  Map<String, String> toJson() => {
    'code': code,
    'name': name,
    'address': address,
    'city': city,
    'tax_id': taxId,
  };
}

/// Resultado de `GET /v1/me/merchant`.
class MerchantLookup {
  final Merchant? merchant;
  final bool unavailable;
  final bool sessionExpired;

  const MerchantLookup.found(Merchant this.merchant)
    : unavailable = false,
      sessionExpired = false;

  const MerchantLookup.missing()
    : merchant = null,
      unavailable = false,
      sessionExpired = false;

  const MerchantLookup.unavailable()
    : merchant = null,
      unavailable = true,
      sessionExpired = false;

  const MerchantLookup.sessionExpired()
    : merchant = null,
      unavailable = false,
      sessionExpired = true;
}

class AuthResponse {
  final bool isSuccess;
  final User? user;
  final Merchant? merchant;
  final String message;
  final bool mustChangePassword;
  final bool sessionExpired;

  const AuthResponse({
    required this.isSuccess,
    this.user,
    this.merchant,
    required this.message,
    this.mustChangePassword = false,
    this.sessionExpired = false,
  });
}
