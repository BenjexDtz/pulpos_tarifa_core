import 'package:geolocator/geolocator.dart';

class MotorGPS {
  // Esta función es el "portero". Revisa si tenemos permiso y prende el GPS.
  static Future<Position?> obtenerUbicacionActual() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    // 1. ¿El usuario tiene el GPS (la antenita) encendido en su celular?
    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      print('⚠️ ALERTA: El GPS del celular está apagado.');
      return null;
    }

    // 2. Revisamos si la app ya tiene permiso
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      // Si no tiene, le lanzamos la ventanita de Android pidiendo permiso
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        print('❌ ERROR: El usuario denegó el permiso del GPS.');
        return null;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      print('❌ ERROR FATAL: Los permisos están denegados permanentemente.');
      return null;
    }

    // 3. Si pasamos todas las barreras de seguridad, ¡leemos el satélite!
    // Usamos 'high' para que sea exacto para un taxi.
    print('🛰️ Conectando a satélites... calculando posición...');
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Nuevo método: Crea un "flujo" de posiciones constantes
  static Stream<Position> obtenerFlujoUbicacion() {
    // Definimos la configuración del rastreo
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Alta precisión para El Alto
      distanceFilter: 10, // Solo nos avisa si el taxi se movió más de 5 metros
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
