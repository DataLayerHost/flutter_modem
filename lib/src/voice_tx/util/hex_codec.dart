/// Returns lowercase hexadecimal without separators.
String bytesToHex(Iterable<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
