import 'dart:typed_data';

/// Abstração para leitura dos blocos CFF.
///
/// Fornece operações de leitura byte a byte com suporte a offsets variáveis
/// (`offSize`) e utilitários para valores assinados/sem sinal.
abstract class DataInput {
  /// Retorna `true` quando ainda há bytes disponíveis.
  ///
  /// Implementações devem lançar [Exception] (ou subclasses) em caso de erro.
  bool hasRemaining();

  /// Posição atual de leitura.
  int getPosition();

  /// Ajusta a posição absoluta de leitura.
  void setPosition(int position);

  /// Lê um byte assinado (-128..127).
  int readByte();

  /// Lê um byte sem sinal (0..255).
  int readUnsignedByte();

  /// Espia um byte sem alterar a posição atual.
  int peekUnsignedByte(int offset);

  /// Lê [length] bytes retornando uma cópia do buffer.
  Uint8List readBytes(int length);

  /// Comprimento total do stream/buffer.
  int length();
}

extension DataInputOps on DataInput {
  /// Lê um valor `short` assinado (16 bits).
  int readShort() {
    final value = readUnsignedShort();
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  /// Lê um valor `unsigned short` (16 bits).
  int readUnsignedShort() {
    final high = readUnsignedByte();
    final low = readUnsignedByte();
    return (high << 8) | low;
  }

  /// Lê um valor inteiro (32 bits) em big-endian.
  int readInt() {
    final b1 = readUnsignedByte();
    final b2 = readUnsignedByte();
    final b3 = readUnsignedByte();
    final b4 = readUnsignedByte();
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  /// Lê um offset com tamanho variável ([offSize] bytes).
  int readOffset(int offSize) {
    var value = 0;
    for (var i = 0; i < offSize; i++) {
      value = (value << 8) | readUnsignedByte();
    }
    return value;
  }
}
