import 'dart:convert';
import 'package:http/http.dart' as http;

class SalesRepository {
  // En Flutter las funciones asíncronas devuelven un Future (el equivalente a Promise)
  Future<bool> processGasSale({
    required String currency,
    required double amount,
    required String cardNumber,
  }) async {
    final url = Uri.parse('https://api.tudominio.aws/v1/sales');

    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'especie_moneda': currency,
          'cantidad': amount,
          'tarjeta_numero': cardNumber,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      // Si el backend normaliza un 200 OK (aprobada)
      return response.statusCode == 200;
    } catch (e) {
      // Manejo básico de errores de comunicación solicitados en la Fase 0
      throw Exception('Error de conexión con el servidor');
    }
  }
}
