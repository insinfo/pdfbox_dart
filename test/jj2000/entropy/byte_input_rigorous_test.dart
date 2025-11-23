import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/ByteInputBuffer.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/ByteToBitInput.dart';

/// Testes RIGOROSOS para ByteToBitInput - operações fundamentais
/// Foco em byte stuffing e overflow que podem causar bugs no MQDecoder
void main() {
  ByteToBitInput _buildInput(Uint8List data, {int offset = 0, int? length}) {
    final sliceLength = length ?? (data.length - offset);
    final buffer = (offset == 0 && sliceLength == data.length)
        ? ByteInputBuffer(data)
        : ByteInputBuffer.view(data, offset, sliceLength);
    return ByteToBitInput(buffer);
  }

  group('ByteToBitInput - Operações Básicas RIGOROSAS', () {
    test('readBit - cada bit de 0xAC (10101100)', () {
      final data = Uint8List.fromList([0xAC]);
      final input = _buildInput(data);
      
      // 0xAC = 0b10101100 (MSB primeiro)
      expect(input.readBit(), 1, reason: 'bit 7 (MSB)');
      expect(input.readBit(), 0, reason: 'bit 6');
      expect(input.readBit(), 1, reason: 'bit 5');
      expect(input.readBit(), 0, reason: 'bit 4');
      expect(input.readBit(), 1, reason: 'bit 3');
      expect(input.readBit(), 1, reason: 'bit 2');
      expect(input.readBit(), 0, reason: 'bit 1');
      expect(input.readBit(), 0, reason: 'bit 0 (LSB)');
    });

    test('readBit - transição entre bytes', () {
      final data = Uint8List.fromList([0xFF, 0x00]);
      final input = _buildInput(data);
      
      // Primeiro byte: 8 bits = 1
      for (int i = 0; i < 8; i++) {
        expect(input.readBit(), 1, reason: 'Bit $i de 0xFF');
      }
      
      // Segundo byte: 8 bits = 0
      for (int i = 0; i < 8; i++) {
        expect(input.readBit(), 0, reason: 'Bit $i de 0x00');
      }
    });

    test('readByte - sequência de bytes', () {
      final data = Uint8List.fromList([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0x01);
      expect(input.readByte(), 0x23);
      expect(input.readByte(), 0x45);
      expect(input.readByte(), 0x67);
      expect(input.readByte(), 0x89);
      expect(input.readByte(), 0xAB);
      expect(input.readByte(), 0xCD);
      expect(input.readByte(), 0xEF);
    });
  });

  group('ByteToBitInput - Byte Stuffing CRÍTICO', () {
    test('0xFF 0x00 - bit stuffing básico', () {
      // JPEG2000: 0xFF seguido de 0x00 = bit stuffing
      // 0x00 deve ser IGNORADO
      final data = Uint8List.fromList([0xFF, 0x00, 0xAB]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0xFF);
      // 0x00 é bit-stuff, deve ser pulado
      expect(input.readByte(), 0xAB);
    });

    test('0xFF 0x00 - verificar se 0x00 é realmente pulado', () {
      final data = Uint8List.fromList([0xFF, 0x00, 0x12]);
      final input = _buildInput(data);
      
      // Ler bit a bit
      for (int i = 0; i < 8; i++) {
        expect(input.readBit(), 1); // Todos bits de 0xFF
      }
      
      // Próximos bits devem ser de 0x12, NÃO de 0x00!
      // 0x12 = 0b00010010
      expect(input.readBit(), 0);
      expect(input.readBit(), 0);
      expect(input.readBit(), 0);
      expect(input.readBit(), 1);
    });

    test('Múltiplos 0xFF 0x00 consecutivos', () {
      final data = Uint8List.fromList([0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0x99]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0xFF);
      expect(input.readByte(), 0xFF);
      expect(input.readByte(), 0xFF);
      expect(input.readByte(), 0x99);
    });

    test('0xFF no final sem 0x00 seguinte', () {
      final data = Uint8List.fromList([0x12, 0xFF]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0x12);
      expect(input.readByte(), 0xFF);
    });

    test('0xFF 0x01 - NÃO é bit stuffing', () {
      // Apenas 0xFF 0x00 é bit stuffing
      // 0xFF 0x01 são dois bytes normais
      final data = Uint8List.fromList([0xFF, 0x01]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0xFF);
      expect(input.readByte(), 0x01);
    });
  });

  group('ByteToBitInput - Offset e Length RIGOROSOS', () {
    test('Offset correto', () {
      final data = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44]);
      final input = _buildInput(data, offset: 2, length: 2); // Offset 2, length 2
      
      expect(input.readByte(), 0x22);
      expect(input.readByte(), 0x33);
    });

    test('Length exato', () {
      final data = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final input = _buildInput(data, length: 2); // Apenas 2 bytes
      
      expect(input.readByte(), 0xAA);
      expect(input.readByte(), 0xBB);
      // Não deve conseguir ler o terceiro byte
    });
  });

  group('ByteToBitInput - Casos que Podem Causar Bug no MQDecoder', () {
    test('Padrão real de bitstream JPEG2000', () {
      // Dados típicos de um code-block
      final data = Uint8List.fromList([
        0x84, 0x00, 0xFF, 0x00, 0x20, 0xFF, 0x00, 0x10
      ]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0x84);
      expect(input.readByte(), 0x00);
      expect(input.readByte(), 0xFF);
      // 0x00 após 0xFF deve ser ignorado
      expect(input.readByte(), 0x20);
      expect(input.readByte(), 0xFF);
      // 0x00 após 0xFF deve ser ignorado
      expect(input.readByte(), 0x10);
    });

    test('Leitura de bits com byte stuffing no meio', () {
      final data = Uint8List.fromList([0xF0, 0xFF, 0x00, 0x0F]);
      final input = _buildInput(data);
      
      // Ler 0xF0 = 0b11110000
      for (int i = 0; i < 4; i++) expect(input.readBit(), 1);
      for (int i = 0; i < 4; i++) expect(input.readBit(), 0);
      
      // Ler 0xFF = 0b11111111
      for (int i = 0; i < 8; i++) expect(input.readBit(), 1);
      
      // 0x00 deve ser ignorado (bit stuffing)
      // Próximo é 0x0F = 0b00001111
      for (int i = 0; i < 4; i++) expect(input.readBit(), 0);
      for (int i = 0; i < 4; i++) expect(input.readBit(), 1);
    });

    test('Overflow de buffer - não deve crashar', () {
      final data = Uint8List.fromList([0x12]);
      final input = _buildInput(data, length: 1);
      
      expect(input.readByte(), 0x12);
      // Ler além do fim - deve ter comportamento definido
      expect(() => input.readByte(), returnsNormally);
    });

    test('Todo 0xFF com byte stuffing', () {
      // 10 bytes: 5x (0xFF 0x00)
      final data = Uint8List(10);
      for (int i = 0; i < 5; i++) {
        data[i * 2] = 0xFF;
        data[i * 2 + 1] = 0x00;
      }
      
      final input = _buildInput(data);
      
      // Deve ler 5 bytes 0xFF (cada 0x00 é ignorado)
      for (int i = 0; i < 5; i++) {
        expect(input.readByte(), 0xFF, reason: '0xFF número $i');
      }
    });
  });

  group('ByteToBitInput - Comparação com Comportamento Java', () {
    test('Sequência idêntica ao TestDecoder.java', () {
      // Dados reais do solid_blue_jj2000.j2k
      final data = Uint8List.fromList([
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
      ]);
      final input = _buildInput(data);
      
      expect(input.readByte(), 0x80);
      for (int i = 0; i < 6; i++) {
        expect(input.readByte(), 0x00);
      }
    });

    test('Padrão alternado - detectar erro de ordem de bits', () {
      // Se bits estiverem na ordem errada, este teste falhará
      final data = Uint8List.fromList([0x55]); // 0b01010101
      final input = _buildInput(data);
      
      // MSB primeiro (padrão JPEG2000)
      expect(input.readBit(), 0);
      expect(input.readBit(), 1);
      expect(input.readBit(), 0);
      expect(input.readBit(), 1);
      expect(input.readBit(), 0);
      expect(input.readBit(), 1);
      expect(input.readBit(), 0);
      expect(input.readBit(), 1);
    });

    test('Bit 0x80 primeiro (MSB)', () {
      final data = Uint8List.fromList([0x80]); // 0b10000000
      final input = _buildInput(data);
      
      expect(input.readBit(), 1); // Bit 7 (MSB)
      for (int i = 0; i < 7; i++) {
        expect(input.readBit(), 0);
      }
    });

    test('Bit 0x01 último (LSB)', () {
      final data = Uint8List.fromList([0x01]); // 0b00000001
      final input = _buildInput(data);
      
      for (int i = 0; i < 7; i++) {
        expect(input.readBit(), 0);
      }
      expect(input.readBit(), 1); // Bit 0 (LSB)
    });
  });
}

