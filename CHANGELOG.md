# Changelog

## 0.2.0

- Rename the package and public library from `dart_modem` to `flutter_modem`.
- Move repository and issue links to DataLayerHost/flutter_modem.
- Align continuous integration and publishing checks with the related Flutter packages.

## 0.1.0

- Initial release with a pure Dart continuous-phase BFSK encoder.
- Add incremental Goertzel decoder, framing, CRC-32, and streaming APIs.
- Add audible 1200-baud and near-ultrasonic BFSK presets.
- Make the 1200-baud V.23 tone pair the phone-oriented default and retain the
  original channel as `Bfsk.poorQuality()` (`Bfsk.robust()` remains an alias).
- Add the CRC-protected READY control frame, padded and repeating encoders,
  duplicate-aware streaming detection, and a pure-Dart wait-state helper.
