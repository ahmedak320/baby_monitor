import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity changes.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Whether the device currently has internet access.
final hasInternetProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true, // assume connected while loading
    error: (_, _) => true,
  );
});
