import 'ready_signal.dart';
import 'ready_signal_detector.dart';
import 'ready_signal_event.dart';

sealed class ReadyWaitResult {
  const ReadyWaitResult();
}

final class ReadyNotDetected extends ReadyWaitResult {
  const ReadyNotDetected();
}

final class ReadyReceived extends ReadyWaitResult {
  const ReadyReceived({
    required this.signal,
    required this.recommendedTransmitDelay,
  });

  final ReadySignal signal;
  final Duration recommendedTransmitDelay;
}

final class ReadyWaitFailed extends ReadyWaitResult {
  const ReadyWaitFailed(this.error);

  final Object error;
}

/// Pure-Dart state helper; callers remain responsible for wall-clock timing.
final class ReadySignalWaiter {
  const ReadySignalWaiter({required this.detector});

  final ReadySignalDetector detector;

  ReadyWaitResult add(Iterable<int> pcm) {
    for (final ReadySignalEvent event in detector.add(pcm)) {
      if (event is ReadySignalDetected && !event.isDuplicate) {
        return ReadyReceived(
          signal: event.signal,
          recommendedTransmitDelay: event.signal.guardDelay,
        );
      }
      if (event is InvalidReadySignal) {
        return ReadyWaitFailed(event.error);
      }
    }
    return const ReadyNotDetected();
  }

  void reset() => detector.reset();
}
