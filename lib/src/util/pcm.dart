import 'dart:typed_data';

const int int16Maximum = 32767;
const int int16Minimum = -32768;

Int16List clampPcm(Iterable<num> samples) => Int16List.fromList(samples
    .map((num sample) => sample.round().clamp(int16Minimum, int16Maximum))
    .toList(growable: false));

double normalizePcmSample(int sample) => sample / 32768.0;
