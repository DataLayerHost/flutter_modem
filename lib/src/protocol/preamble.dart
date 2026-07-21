abstract final class Preamble {
  static const int syncWord = 0xd391;
  static const int syncWordBits = 16;

  static int bitAt(int index) => index.isEven ? 1 : 0;

  static List<int> bits(int length) =>
      List<int>.generate(length, bitAt, growable: false);
}
