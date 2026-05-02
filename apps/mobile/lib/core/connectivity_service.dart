import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream simples `bool isOnline` derivado do `connectivity_plus`.
///
/// Considera online qualquer resultado != none. A verificação real
/// (DNS/HTTP reachable) fica a cargo do Dio.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield isOnline(await conn.checkConnectivity());
  yield* conn.onConnectivityChanged.map(isOnline);
});
