// Función principal que ejecuta Dart al correr el archivo

// Tu modelo matemático convertido en código real
double calcularTarifa({
  required double distanciaKm,
  required double costoBaseKm,
  required double factorAltitud,
  required double factorSuperficie,
  required double tiempoDetencionMin,
  required double costoMinutoDetencion,
}) {
  // Fórmula: T = D * Cb * FH * FR + Ct * Td
  double costoRecorrido =
      distanciaKm * costoBaseKm * factorAltitud * factorSuperficie;
  double costoDetencion = tiempoDetencionMin * costoMinutoDetencion;

  double tarifaTotal = costoRecorrido + costoDetencion;

  return tarifaTotal;
}
