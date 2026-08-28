# Flutter Modem

`flutter_modem` is a pure Dart acoustic modem. It turns arbitrary bytes into signed
16-bit PCM audio and incrementally reconstructs validated packets from PCM. The
core has no Flutter, native-code, audio-device, or runtime-specific dependency,
so it can be used on the Dart VM, servers, Flutter, and Dart-to-Wasm targets.

## Quick start

```dart
import 'dart:convert';

import 'package:flutter_modem/flutter_modem.dart';

final modem = FlutterModem(modulation: const Bfsk());
final pcm = modem.encode(utf8.encode('Hello'));

final decoder = modem.createStreamingDecoder();
decoder.frames.listen((frame) {
  print(utf8.decode(frame.payload));
});
decoder.feed(pcm);
```

The PCM output is an `Int16List`. Playing or recording it is deliberately left
to the host application, which keeps the modem platform-independent.

## Application protocol

`FlutterModem` uses Voice Transaction Protocol version 1 by default. Each input is
treated as an already-signed transaction, wrapped in a SHA-256/CRC-protected
envelope, split into Voice TX DATA packets, and reassembled by the matching
decoder. Configure the chain identifiers for production use:

```dart
final modem = FlutterModem(
  protocol: const VoiceTxModemProtocol(
    blockchainId: 1,
    networkId: 1,
  ),
);
```

The default identifiers are zero when the application does not supply them.
Empty payloads are invalid under Voice TX. The complete Voice TX packet,
envelope, assembly, and sender/receiver session APIs are exported directly by
`flutter_modem`.

To use only the modem's basic `DMOD` transport framing, disable the application
protocol explicitly:

```dart
final rawModem = FlutterModem(protocol: null);
// Equivalent when a non-null ModemProtocol value is needed:
final identityModem = FlutterModem(protocol: const NoModemProtocol());
```

Another protocol can replace Voice TX by implementing `ModemProtocol` and its
stateful `ModemProtocolDecoder`. A protocol may turn one application payload
into multiple transport packets; the decoder emits a frame only after the
application payload is complete.

## How BFSK works

Binary frequency-shift keying (BFSK) represents each bit with one of two sine
frequencies. The phone-oriented default follows the forward-channel tones and
rate of ITU-T V.23 mode 2: `0` is 2100 Hz, `1` is 1300 Hz, and the channel runs
at 1200 baud. At 48000 samples per second, every bit occupies exactly 40
samples. The encoder carries the sine phase across bit boundaries, avoiding
discontinuities caused by restarting every tone at phase zero.

All physical settings are configurable:

```dart
const modulation = Bfsk(
  sampleRate: 48000,
  baudRate: 1200,
  zeroFrequency: 2100,
  oneFrequency: 1300,
);

print(modulation.samplesPerBit); // 40
```

### Near-ultrasonic alternative

For hardware with a usable high-frequency audio path, select the built-in
near-ultrasonic preset:

```dart
final modem = FlutterModem(
  modulation: const Bfsk.ultrasonic(),
);

final pcm = modem.encode(payload); // 48 kHz signed Int16 PCM
final decoder = modem.createStreamingDecoder();
decoder.frames.listen((frame) => handle(frame.payload));
decoder.feed(recordedPcm);
```

This preset uses 18.5 kHz for `0`, 19.5 kHz for `1`, a 48 kHz sample rate, and
100 baud. It is near-ultrasonic rather than guaranteed inaudible: some people
can hear tones in this range, and many phones, speakers, microphones, codecs,
telephone networks, and noise-suppression systems attenuate or remove them.
Both playback and capture must preserve mono 48 kHz PCM. Test on every target
device and provide a visible disclosure when transmitting high-frequency audio.

The current symbol clock requires `sampleRate` to be evenly divisible by
`baudRate`. Frequencies should be below the Nyquist frequency (half the sample
rate) and should be selected for the response of the real audio channel.

### Robust low-speed mode

For noisy, filtered, or codec-damaged calls where throughput is less important,
use the 100-baud poor-quality profile:

```dart
final modem = FlutterModem(
  modulation: const Bfsk.poorQuality(),
);
```

It uses 8 kHz PCM with 1200/2200 Hz tones and 80 samples per bit. The older
`Bfsk.robust()` name remains available as an alias.

### Orthogonal high-speed alternative

The `fast` preset is an alternative 1200-baud audible channel:

```dart
final modem = FlutterModem(
  modulation: const Bfsk.fast(),
);

final pcm = modem.encode(payload); // 48 kHz signed Int16 PCM
final decoder = modem.createStreamingDecoder();
```

It uses 1200 Hz and 2400 Hz tones at a 48 kHz sample rate. Each 40-sample
symbol contains exactly one or two tone cycles, which gives the two Goertzel
detectors clean frequency separation. Unlike the default, its tones are not the
V.23 telephone pair.

## Goertzel decoding and synchronization

The decoder evaluates two Goertzel filters per symbol: one at the zero
frequency and one at the one frequency. The stronger detector supplies the bit.
Goertzel computes energy at a chosen frequency directly, so no FFT is used.

Reception is incremental. The decoder buffers only one symbol while searching
for the alternating preamble and 16-bit sync word. Once synchronized, it reads
the packet header to learn the bounded payload size, then emits only a complete
packet with a valid CRC-32.

## Wire and packet format

Fields are transmitted most-significant bit first. Multi-byte integers are big
endian.

| Layer | Field | Default size | Purpose |
| --- | --- | ---: | --- |
| Frame | Carrier | 24 bits | Gives receivers time to observe a tone |
| Frame | Alternating preamble | 48 bits | Establishes the repeating bit pattern |
| Frame | Sync word | 16 bits | Marks the exact packet boundary (`0xD391`) |
| Packet | Magic | 4 bytes | ASCII `DMOD` |
| Packet | Version | 1 byte | Currently `1` |
| Packet | Payload length | 4 bytes | Unsigned byte count |
| Packet | Payload | variable | Application bytes |
| Packet | CRC-32 | 4 bytes | IEEE CRC-32 over magic through payload |

Malformed magic, unsupported versions, oversized lengths, truncated packets,
and CRC failures are rejected. The default maximum payload is 1 MiB and can be
lowered through `Bfsk.maximumPayloadLength` for constrained receivers.

## Streaming

Feed chunks of any size; chunk boundaries do not need to align with symbols:

```dart
final decoder = StreamingBfskDecoder();
decoder.frames.listen((frame) => handle(frame.payload));

decoder.feed(firstPcmChunk);
decoder.feed(secondPcmChunk);
await decoder.close();
```

For a synchronous pipeline, `BfskDecoder.feed` returns the frames completed by
that call. `StreamingBfskEncoder.bind` maps each incoming payload to a separate
PCM frame.

## Telephone and acoustic use cases

The default 1300/2100 Hz tones fit within conventional 300-3400 Hz telephone
audio and use the V.23 mode 2 bit mapping. This makes the modem useful over
telephone audio, intercoms, speakers and
microphones, audio cables, device pairing, and low-rate telemetry. Real channels
add gain control, filtering, echo, clock drift, clipping, and noise. Resample
captured audio to the configured rate and supply mono signed Int16 PCM. Test the
chosen frequencies and baud rate against the actual channel before deployment.

The waveform uses V.23-compatible frequencies and bitrate, but flutter_modem's
packet framing is its own protocol; it does not claim byte-level interoperability
with legacy V.23 terminals. Speech codecs, echo cancellation, automatic gain
control, and noise suppression can still damage modem audio. An uncompressed
G.711 path is preferable where the call stack exposes that choice.

`flutter_modem` only generates and analyzes waveforms. A Flutter application can
connect it to any suitable audio capture/playback package without coupling that
package to the modem core.

## More examples

Runnable programs are in [`example/`](example/):

- `encode_hello.dart` encodes “Hello”.
- `decode_hello.dart` demonstrates incremental decoding.
- `encode_random_bytes.dart` encodes random binary data.
- `loopback.dart` verifies a full in-memory round trip.
- `fast_loopback.dart` exercises the audible 1200-baud preset.
- `ultrasonic_loopback.dart` exercises the near-ultrasonic preset.
- `ready_phone_flow.dart` demonstrates phone-side READY detection.
- `ready_server.dart` demonstrates lazy repeated READY generation.

Hex conversion helpers are also exported:

```dart
final bytes = hexToBytes('00 ca fe ff');
print(bytesToHex(bytes)); // 00cafeff
```

## READY handshake for half-duplex calls

READY is a compact control signal sent by the receiving side before transaction
audio. It tells the phone-side sender that the receiver has answered, is
listening, and permits transmission after a decoded guard delay.

```text
Receiver answers
→ receiver repeats READY
→ phone microphone captures READY
→ flutter_modem detects READY
→ app waits guard delay
→ app plays transaction audio
→ receiver stops READY transmission when transaction preamble is detected
```

The receiver repeats READY because microphone capture may begin in the middle of
a signal or the first signal may be damaged. Repetitions retain one session ID;
their sequence number increments by default. The detector remembers a bounded
number of sessions and emits only the first READY for each session unless
`emitDuplicates` is enabled.

### READY control frame

READY is transported as a normal CRC-32-protected modem payload and also has its
own CRC-16/CCITT-FALSE check. Its fixed 16-byte, big-endian format is:

| Field | Size | Value or meaning |
| --- | ---: | --- |
| Magic | 2 bytes | ASCII `DM` |
| Control version | 1 byte | `1` |
| Control type | 1 byte | READY = `1` |
| Session ID | 4 bytes | Unsigned session identity |
| Flags | 1 byte | Defined optional behavior |
| Guard delay | 2 bytes | Milliseconds before sender playback |
| Receiver timeout | 1 byte | Seconds the receiver remains ready |
| Sequence | 2 bytes | Repetition sequence number |
| CRC-16 | 2 bytes | CCITT-FALSE over the preceding 14 bytes |

Other stable control-type numbers are reserved for acknowledgement, negative
acknowledgement, accepted, rejected, and error frames. READY is the only control
behavior implemented in this release.

### Receiver/server generation

```dart
final modem = FlutterModem();
final ready = ReadySignal(
  sessionId: secureSessionId,
  guardDelay: const Duration(milliseconds: 500),
  receiverTimeout: const Duration(seconds: 10),
);
final repeater = RepeatingReadySignalEncoder(
  modem: modem,
  ready: ready,
  repeatInterval: const Duration(milliseconds: 300),
  maximumRepeats: 20,
);

for (final pcm in repeater.chunks()) {
  audioOutput.send(pcm);
  if (transactionPreambleDetected) break;
}
```

`chunks()` is synchronous and lazy. It alternates one complete padded READY PCM
block with one silence block; it does not wait in real time. `encodeAll()` creates
one complete buffer and rejects output exceeding `maximumTotalDuration`.

### Phone-side detection

```dart
final detector = ReadySignalDetector(
  modemDecoder: modem.createStreamingDecoder(),
);

void onMicrophonePcm(Int16List chunk) {
  for (final event in detector.add(chunk)) {
    if (event is ReadySignalDetected && !event.isDuplicate) {
      final delay = event.signal.guardDelay;
      // App stops capture, waits for delay, then plays prepared transaction PCM.
    }
  }
}
```

`ReadySignalWaiter` provides the same flow as `ReadyNotDetected`, `ReadyReceived`,
or `ReadyWaitFailed`; `ReadyReceived.recommendedTransmitDelay` is the decoded
guard delay. No timers are started by the package.

Flutter code remains responsible for microphone capture, audio playback, call
UI, routing, permissions, lifecycle, and waiting. A server or Asterisk adapter
remains responsible for call answering and writing these PCM chunks at the
configured real-time sample rate.

### READY security and call limitations

CRC detects accidental corruption; it does not authenticate or encrypt READY.
Applications should generate unpredictable session IDs, bind them to expected
transactions, limit timeouts and replay windows, and authenticate sensitive
transaction payloads separately. Duplicate suppression is local state, not
replay protection across process restarts.

Cellular and VoIP paths may apply speech codecs, resampling, voice activity
detection, automatic gain control, echo cancellation, and noise suppression.
These can delay or destroy modem tones. Tests cover deterministic chunking,
25-percent amplitude, moderate seeded white noise, symmetric clipping, and one
G.711 mu-law round trip, but every target call path still needs end-to-end
qualification.

## Protocol evolution

Configuration, waveform generation, detection, synchronization, and packet
framing are separate modules. This keeps room for pluggable Bell 103, Bell 202,
V.21, MFSK, and PSK implementations without putting platform audio code in the
protocol core. Wire compatibility is versioned independently through the packet
header.

## Development and publishing

```sh
dart pub get
dart analyze
dart test
dart pub publish --dry-run
```

Publishing uses pub.dev's GitHub OIDC workflow for tags such as `0.1.0`. The
first release must be published manually, then automated publishing must be
enabled in the package's pub.dev Admin tab for this repository with tag pattern
`{{version}}`.

## License

[CORE License](LICENSE). Distribution of covered source code, including
modifications and contributions, must remain publicly available.
