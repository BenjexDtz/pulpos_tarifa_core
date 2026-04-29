import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Modelo de parámetros ─────────────────────────────────────────────────────
class ParametrosTopograficos {
  final int id;
  final String zonaCiudad;
  final double costoBaseKm;
  final double factorAltitud;
  final double factorSuperficie;
  final double costoMinutoDetencion;

  const ParametrosTopograficos({
    required this.id,
    required this.zonaCiudad,
    required this.costoBaseKm,
    required this.factorAltitud,
    required this.factorSuperficie,
    required this.costoMinutoDetencion,
  });

  factory ParametrosTopograficos.fromJson(Map<String, dynamic> json) {
    return ParametrosTopograficos(
      id: json['id'],
      zonaCiudad: json['zona_ciudad'],
      costoBaseKm: double.parse(json['costo_base_km'].toString()),
      factorAltitud: double.parse(json['factor_altitud'].toString()),
      factorSuperficie: double.parse(json['factor_superficie'].toString()),
      costoMinutoDetencion: double.parse(
        json['costo_minuto_detencion'].toString(),
      ),
    );
  }

  // Valores por defecto si el servidor no responde (modo offline)
  static const ParametrosTopograficos porDefecto = ParametrosTopograficos(
    id: 1,
    zonaCiudad: 'El Alto - Topografía Compleja',
    costoBaseKm: 2.00,
    factorAltitud: 1.40,
    factorSuperficie: 2.50,
    costoMinutoDetencion: 0.50,
  );
}

// ─── Servicio de parámetros ───────────────────────────────────────────────────
class ParametrosService {
  static const String _urlBase = 'http://192.168.0.102:3000'; // ⚠️ Cambia tu IP
  static const String _cacheKey = 'parametros_topograficos';

  /// Descarga los parámetros del servidor.
  /// Si no hay conexión, usa los guardados localmente (caché).
  /// Si tampoco hay caché, usa los valores por defecto.
  static Future<ParametrosTopograficos> obtener() async {
    try {
      final response = await http
          .get(Uri.parse('$_urlBase/api/parametros'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final params = ParametrosTopograficos.fromJson(data);
          // Guardar en caché local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, response.body);
          print(
            '✅ Parámetros descargados del servidor: Cb=${params.costoBaseKm} FH=${params.factorAltitud}',
          );
          return params;
        }
      }
    } catch (e) {
      print('⚠️ Sin conexión al servidor, usando caché: $e');
    }

    // Intentar usar caché
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        print('📦 Parámetros desde caché local.');
        return ParametrosTopograficos.fromJson(jsonDecode(cached));
      }
    } catch (_) {}

    // Último recurso: valores por defecto hardcodeados
    print('⚙️ Usando parámetros por defecto (sin red ni caché).');
    return ParametrosTopograficos.porDefecto;
  }
}

// ─── Fórmula tarifaria ────────────────────────────────────────────────────────
// T = D * Cb * FH * FR + Ct * Td
//
// D  = distancia en km
// Cb = costo base por km (desde servidor)
// FH = factor de altitud (desde servidor)
// FR = factor de superficie (asfalto=1.0, tierra=2.5 — elige el conductor)
// Ct = costo por minuto de detención (desde servidor)
// Td = tiempo de detención en minutos
double calcularTarifa({
  required double distanciaKm,
  required double costoBaseKm,
  required double factorAltitud,
  required double factorSuperficie,
  required double tiempoDetencionMin,
  required double costoMinutoDetencion,
}) {
  final costoRecorrido =
      distanciaKm * costoBaseKm * factorAltitud * factorSuperficie;
  final costoDetencion = tiempoDetencionMin * costoMinutoDetencion;
  return costoRecorrido + costoDetencion;
}
