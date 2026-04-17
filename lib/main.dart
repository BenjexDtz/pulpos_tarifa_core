import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'motor_gps.dart';
import 'calculadora.dart';
import 'base_datos.dart';
import 'pantalla_historial.dart';
import 'pantalla_login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AplicacionPulpos());
}

class AplicacionPulpos extends StatelessWidget {
  const AplicacionPulpos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Radio Taxis Pulpos',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: const PantallaLogin(),
    );
  }
}

class PantallaPrueba extends StatefulWidget {
  const PantallaPrueba({super.key});

  @override
  State<PantallaPrueba> createState() => _PantallaPruebaState();
}

class _PantallaPruebaState extends State<PantallaPrueba> {
  double distanciaTotalKm = 0.0;
  Position? posicionAnterior;
  bool enViaje = false;
  StreamSubscription<Position>? suscripcionGPS;
  // --- Variables para el tiempo de detención ---
  int segundosDetencion = 0;
  Timer? relojDetencion;
  bool estaDetenido = false;

  // Parámetros topográficos
  final double costoBase = 2.0;
  final double fAltitud = 1.4;

  double fSuperficie = 1.0;

  // ==========================================
  // 🔥 FUNCIÓN: SINCRONIZAR VIAJES (ahora en el State, donde corresponde)
  // ==========================================
  Future<void> sincronizarViajesPendientes() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Sincronizando viajes con la central...'),
      ),
    );

    final db = await BaseDatosLocal.instancia.database;
    final pendientes = await db.query(
      'viajes',
      where: 'estado_sincronizacion = ?',
      whereArgs: [0],
    );

    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Todo al día. No hay viajes pendientes.'),
        ),
      );
      return;
    }

    int viajesEnviados = 0;

    for (var viaje in pendientes) {
      try {
        // ⚠️ ¡ATENCIÓN! CAMBIA ESTO POR LA IP DE TU COMPUTADORA
        final url = Uri.parse('http://192.168.0.9:3000/api/viajes/sincronizar');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chofer_id': viaje['chofer_id'],
            'distancia_km': viaje['distancia_km'],
            'tiempo_detencion_min': viaje['tiempo_detencion_min'],
            'tarifa_cobrada': viaje['tarifa_total'],
            'fecha_hora_viaje': viaje['fecha_hora'],
          }),
        );

        if (response.statusCode == 201) {
          await db.update(
            'viajes',
            {'estado_sincronizacion': 1},
            where: 'id = ?',
            whereArgs: [viaje['id']],
          );
          viajesEnviados++;
        }
      } catch (e) {
        print("Error de red: $e");
      }
    }

    if (context.mounted && viajesEnviados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📡 Éxito: $viajesEnviados viajes subidos a gerencia.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void iniciarRelojDetencion() {
    relojDetencion = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (enViaje && posicionAnterior != null) {
        if (posicionAnterior!.speed < 0.5) {
          setState(() {
            segundosDetencion++;
            estaDetenido = true;
          });
        } else {
          setState(() {
            estaDetenido = false;
          });
        }
      }
    });
  }

  void iniciarRastreo() async {
    final posInicial = await MotorGPS.obtenerUbicacionActual();
    if (posInicial == null) return;

    setState(() {
      distanciaTotalKm = 0.0;
      segundosDetencion = 0;
      posicionAnterior = posInicial;
      enViaje = true;
    });

    iniciarRelojDetencion();

    suscripcionGPS = MotorGPS.obtenerFlujoUbicacion().listen((
      Position nuevaPosicion,
    ) {
      if (nuevaPosicion.accuracy > 20.0) return;

      if (posicionAnterior != null) {
        double distanciaMetros = Geolocator.distanceBetween(
          posicionAnterior!.latitude,
          posicionAnterior!.longitude,
          nuevaPosicion.latitude,
          nuevaPosicion.longitude,
        );
        setState(() {
          distanciaTotalKm += (distanciaMetros / 1000);
        });
      }
      posicionAnterior = nuevaPosicion;
    });
  }

  void detenerRastreo() async {
    suscripcionGPS?.cancel();
    relojDetencion?.cancel();

    double tarifaFinal = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      tiempoDetencionMin: (segundosDetencion / 60),
      costoMinutoDetencion: 0.5,
    );

    final prefs = await SharedPreferences.getInstance();
    int idChoferReal = prefs.getInt('chofer_id') ?? 1;

    Map<String, dynamic> nuevoViaje = {
      'chofer_id': idChoferReal,
      'distancia_km': distanciaTotalKm,
      'tiempo_detencion_min': (segundosDetencion / 60),
      'factor_altitud': fAltitud,
      'factor_superficie': fSuperficie,
      'tarifa_total': tarifaFinal,
      'estado_sincronizacion': 0,
      'fecha_hora': DateTime.now().toIso8601String(),
    };

    int id = await BaseDatosLocal.instancia.insertarViaje(nuevoViaje);

    setState(() {
      enViaje = false;
      fSuperficie = 1.0;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Viaje guardado. Total: Bs ${tarifaFinal.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    suscripcionGPS?.cancel();
    relojDetencion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double tarifaEnVivo = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      tiempoDetencionMin: (segundosDetencion / 60),
      costoMinutoDetencion: 0.5,
    );

    return Scaffold(
      backgroundColor: enViaje ? Colors.black : Colors.grey[100],
      appBar: enViaje
          ? null
          : AppBar(
              title: const Text(
                'Radio Taxis Pulpos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: enViaje ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: enViaje
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                    border: enViaje
                        ? Border.all(color: Colors.greenAccent, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (enViaje)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.satellite_alt,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'SISTEMA ACTIVO',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: enViaje ? 20 : 0),

                      Text(
                        'TARIFA ACTUAL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: enViaje ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                      Text(
                        'Bs ${tarifaEnVivo.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: enViaje ? Colors.white : Colors.green[700],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        child: Divider(color: Colors.grey),
                      ),

                      Text(
                        'DISTANCIA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: enViaje ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                      Text(
                        '${distanciaTotalKm.toStringAsFixed(3)} KM',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: enViaje ? Colors.white : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'TIPO DE RUTA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: enViaje ? Colors.grey[500] : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text(
                              'ASFALTO',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            selected: fSuperficie == 1.0,
                            onSelected: (bool selected) {
                              setState(() {
                                fSuperficie = 1.0;
                              });
                            },
                            selectedColor: Colors.blue[800],
                            backgroundColor: enViaje
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            labelStyle: TextStyle(
                              color: fSuperficie == 1.0
                                  ? Colors.white
                                  : (enViaje ? Colors.grey[300] : Colors.black),
                            ),
                          ),
                          const SizedBox(width: 15),
                          ChoiceChip(
                            label: const Text(
                              'TIERRA / COMPLEJO',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            selected: fSuperficie == 2.5,
                            onSelected: (bool selected) {
                              setState(() {
                                fSuperficie = 2.5;
                              });
                            },
                            selectedColor: Colors.orange[800],
                            backgroundColor: enViaje
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            labelStyle: TextStyle(
                              color: fSuperficie == 2.5
                                  ? Colors.white
                                  : (enViaje ? Colors.grey[300] : Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              if (!enViaje) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('HISTORIAL'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          foregroundColor: Colors.blue[800],
                          side: BorderSide(color: Colors.blue[800]!),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PantallaHistorial(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('SINC. NUBE'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[700]!),
                        ),
                        onPressed: sincronizarViajesPendientes,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
              ],

              ElevatedButton.icon(
                icon: Icon(
                  enViaje ? Icons.stop_circle : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 28,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: enViaje ? Colors.red[700] : Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  enViaje ? 'FINALIZAR VIAJE Y COBRAR' : 'INICIAR NUEVO VIAJE',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  if (enViaje) {
                    detenerRastreo();
                  } else {
                    iniciarRastreo();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
