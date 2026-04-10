import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Tipografía un poco más moderna para los números
        fontFamily: 'Roboto',
      ),
      home: const PantallaPrueba(),
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

  // Parámetros topográficos fijos por ahora (El Alto)
  final double costoBase = 2.0;
  final double fAltitud = 1.4;
  final double fSuperficie = 2.5;

  void iniciarRastreo() async {
    final posInicial = await MotorGPS.obtenerUbicacionActual();
    if (posInicial == null) return;

    setState(() {
      distanciaTotalKm = 0.0;
      posicionAnterior = posInicial;
      enViaje = true;
    });

    suscripcionGPS = MotorGPS.obtenerFlujoUbicacion().listen((
      Position nuevaPosicion,
    ) {
      if (nuevaPosicion.accuracy > 20.0) return; // Filtro anti-fantasmas

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

    // Calculamos el precio final real
    double tarifaFinal = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      tiempoDetencionMin: 0.0, // Pendiente para la Fase 5
      costoMinutoDetencion: 0.5,
    );

    // Guardamos el viaje real en SQLite
    Map<String, dynamic> nuevoViaje = {
      'distancia_km': distanciaTotalKm,
      'tiempo_detencion_min': 0.0,
      'factor_altitud': fAltitud,
      'factor_superficie': fSuperficie,
      'tarifa_total': tarifaFinal,
      'estado_sincronizacion': 0,
      'fecha_hora': DateTime.now().toIso8601String(),
    };

    int id = await BaseDatosLocal.instancia.insertarViaje(nuevoViaje);

    setState(() {
      enViaje = false;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Viaje #$id guardado. Total a cobrar: Bs ${tarifaFinal.toStringAsFixed(2)}',
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos la tarifa en vivo para mostrarla en la pantalla
    double tarifaEnVivo = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      tiempoDetencionMin: 0.0,
      costoMinutoDetencion: 0.5,
    );

    return Scaffold(
      // Si está en viaje, el fondo se vuelve negro (Modo Noche/Dashboard)
      backgroundColor: enViaje ? Colors.black : Colors.grey[100],
      appBar: enViaje
          ? null // Ocultamos la barra superior para que parezca un taxímetro puro
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
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Estira los botones
            children: [
              // --- PANEL CENTRAL DE DATOS ---
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
                    // Borde verde brillante si está en viaje
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

                      SizedBox(height: enViaje ? 30 : 0),

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
                          vertical: 20,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- BOTONES DE CONTROL ---
              // Solo mostramos el historial y simulación si NO estamos en viaje
              if (!enViaje) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('HISTORIAL DE VIAJES'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(15),
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
                const SizedBox(height: 15),
              ],

              // El botón principal (Iniciar/Detener)
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
