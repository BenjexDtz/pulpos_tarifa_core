import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'motor_gps.dart';
import 'calculadora.dart';
import 'base_datos.dart';
import 'pantalla_historial.dart';
import 'pantalla_login.dart';

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
      // 🔥 CAMBIO AQUÍ: Ahora arrancamos en la puerta de entrada
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
  int segundosDetencion = 0; // Acumulador de segundos parados
  Timer? relojDetencion; // El cronómetro que hará "tic-tac"
  bool estaDetenido = false; // Estado actual del vehículo

  // Parámetros topográficos
  final double costoBase = 2.0;
  final double fAltitud = 1.4; // Sigue fijo por ahora

  // 🔥 ¡La magia! Ahora es dinámica. Empieza en 1.0 (Asfalto)
  double fSuperficie = 1.0;

  void iniciarRelojDetencion() {
    relojDetencion = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (enViaje && posicionAnterior != null) {
        // Si la velocidad es menor a 0.5 m/s (casi quieto)
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
      segundosDetencion = 0; //Empezamos con 0 segundos de trancadera
      posicionAnterior = posInicial;
      enViaje = true;
    });

    iniciarRelojDetencion(); //Encendemos el cronómetro

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
    relojDetencion?.cancel(); //Apagamos el reloj para que no consuma memoria

    double tarifaFinal = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      // 🔥 NUEVO: Convertimos los segundos a minutos reales
      tiempoDetencionMin: (segundosDetencion / 60),
      costoMinutoDetencion: 0.5,
    );

    Map<String, dynamic> nuevoViaje = {
      'distancia_km': distanciaTotalKm,
      // 🔥 NUEVO: Guardamos el tiempo real en SQLite
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
      fSuperficie = 1.0; // Reseteamos a asfalto al terminar
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double tarifaEnVivo = calcularTarifa(
      distanciaKm: distanciaTotalKm,
      costoBaseKm: costoBase,
      factorAltitud: fAltitud,
      factorSuperficie: fSuperficie,
      // Aquí también convertimos los segundos a minutos
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

                      // 🔥 NUEVO: Selector de Superficie
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
