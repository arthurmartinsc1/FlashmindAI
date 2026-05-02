/// Configuração do app, lida via `--dart-define` no build.
///
/// Em emulador Android use `10.0.2.2`, em iOS Simulator `localhost`,
/// em dispositivo físico use o IP da máquina dev na mesma LAN.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const Duration httpTimeout = Duration(seconds: 15);
}
