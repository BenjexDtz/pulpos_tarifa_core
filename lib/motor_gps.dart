import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'; // 🔥 NUEVO IMPORT NECESARIO

class MotorGPS {
  static Future<Position?> obtenerUbicacionActual() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) return null;

    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return null;
    }

    if (permiso == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // 🔥 AQUÍ ESTÁ LA MAGIA DEL ESCUDO (FOREGROUND SERVICE)
  static Stream<Position> obtenerFlujoUbicacion() {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Configuración especial para que Android no mate la app
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Calculando tarifa y distancia...",
          notificationTitle: "Radio Taxis Pulpos Activo 🚖",
          enableWakeLock: true, // Evita que el procesador se duerma
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
