import 'dart:async'; // Necesario para mantener la conexión abierta con el GPS
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Para calcular distancias
import 'motor_gps.dart';
import 'calculadora.dart';
import 'base_datos.dart';
import 'pantalla_historial.dart';

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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PantallaPrueba(),
    );
  }
}

// 🔥 EVOLUCIÓN: Ahora es un StatefulWidget (Tiene memoria) 🔥
class PantallaPrueba extends StatefulWidget {
  const PantallaPrueba({super.key});

  @override
  State<PantallaPrueba> createState() => _PantallaPruebaState();
}

class _PantallaPruebaState extends State<PantallaPrueba> {
  // --- TUS NUEVAS VARIABLES DE ESTADO ---
  double distanciaTotalKm = 0.0;
  Position? posicionAnterior;
  bool enViaje = false;
  StreamSubscription<Position>?
  suscripcionGPS; // El cable que nos conecta al satélite

  // --- FUNCIÓN PARA ARRANCAR EL TAXÍMETRO ---
  void iniciarRastreo() async {
    // Primero verificamos que el GPS funcione y tenga permisos
    final posInicial = await MotorGPS.obtenerUbicacionActual();
    if (posInicial == null) return; // Si no hay permiso, no hacemos nada

    setState(() {
      distanciaTotalKm = 0.0;
      posicionAnterior = posInicial;
      enViaje = true;
    });

    // Abrimos el micrófono al satélite (Stream)
    suscripcionGPS = MotorGPS.obtenerFlujoUbicacion().listen((
      Position nuevaPosicion,
    ) {
      if (nuevaPosicion.accuracy > 20.0) {
        print(
          '👻 Señal rebotando (Margen: ${nuevaPosicion.accuracy}m). Ignorando...',
        );
        return; // Si el margen de error es mayor a 20 metros, descartamos el dato.
      }

      if (posicionAnterior != null) {
        // Calculamos la distancia entre el punto anterior y el nuevo
        double distanciaMetros = Geolocator.distanceBetween(
          posicionAnterior!.latitude,
          posicionAnterior!.longitude,
          nuevaPosicion.latitude,
          nuevaPosicion.longitude,
        );

        setState(() {
          distanciaTotalKm +=
              (distanciaMetros / 1000); // Convertimos metros a KM
        });
      }
      posicionAnterior = nuevaPosicion;
      print(
        '📍 Movimiento detectado. Acumulado: ${distanciaTotalKm.toStringAsFixed(3)} km',
      );
    });
  }

  // --- FUNCIÓN PARA FRENAR EL TAXÍMETRO ---
  void detenerRastreo() {
    suscripcionGPS?.cancel(); // Cortamos la llamada satelital
    setState(() {
      enViaje = false;
    });

    // Mostramos cuánto recorrió en total
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🛑 Viaje finalizado. Recorriste: ${distanciaTotalKm.toStringAsFixed(2)} km',
          ),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  // Por seguridad, si la app se cierra, apagamos el GPS
  @override
  void dispose() {
    suscripcionGPS?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de Sistema - El Alto')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- BOTÓN 1: LA SIMULACIÓN (Mantenemos tu código seguro) ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.orange,
              ),
              onPressed: enViaje
                  ? null
                  : () async {
                      // Se desactiva si estás en viaje real
                      double tarifaFinal = calcularTarifa(
                        distanciaKm: 5.0,
                        costoBaseKm: 2.0,
                        factorAltitud: 1.4,
                        factorSuperficie: 2.5,
                        tiempoDetencionMin: 10.0,
                        costoMinutoDetencion: 0.5,
                      );

                      Map<String, dynamic> nuevoViaje = {
                        'distancia_km': 5.0,
                        'tiempo_detencion_min': 10.0,
                        'factor_altitud': 1.4,
                        'factor_superficie': 2.5,
                        'tarifa_total': tarifaFinal,
                        'estado_sincronizacion': 0,
                        'fecha_hora': DateTime.now().toIso8601String(),
                      };

                      int id = await BaseDatosLocal.instancia.insertarViaje(
                        nuevoViaje,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Guardado. ID: $id | Bs $tarifaFinal',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: const Text(
                'SIMULAR CARRERA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- BOTÓN 2: HISTORIAL ---
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text(
                'VER HISTORIAL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: enViaje
                  ? null
                  : () {
                      // Se desactiva si estás en viaje real
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaHistorial(),
                        ),
                      );
                    },
            ),

            const SizedBox(height: 40),
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // --- PANEL DEL TAXÍMETRO REAL ---
            Text(
              'Distancia Real Recorrida',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              '${distanciaTotalKm.toStringAsFixed(3)} KM', // Muestra 3 decimales para ver los metros
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: enViaje ? Colors.red : Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            // --- BOTÓN 3: INICIAR / DETENER RASTREO (STREAM) ---
            ElevatedButton.icon(
              icon: Icon(
                enViaje ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                backgroundColor: enViaje ? Colors.red[900] : Colors.green[700],
              ),
              label: Text(
                enViaje ? 'DETENER TAXÍMETRO' : 'INICIAR TAXÍMETRO',
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
    );
  }
}
