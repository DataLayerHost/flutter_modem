import 'ready_signal.dart';

sealed class ReadySignalEvent {
  const ReadySignalEvent();
}

final class ReadySignalDetected extends ReadySignalEvent {
  const ReadySignalDetected({required this.signal, required this.isDuplicate});

  final ReadySignal signal;
  final bool isDuplicate;
}

final class InvalidReadySignal extends ReadySignalEvent {
  const InvalidReadySignal(this.error);

  final ReadySignalDecodeException error;
}
