import 'dart:convert';
import 'dart:typed_data';

class STCharacterPngCodec {
  const STCharacterPngCodec();

  static const List<int> _pngSignature = [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  String? readCharaText(Uint8List bytes) {
    if (!_hasPngSignature(bytes)) return null;

    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length = _readUint32(bytes, offset);
      offset += 4;
      if (offset + 4 + length + 4 > bytes.length) return null;

      final type = ascii.decode(bytes.sublist(offset, offset + 4));
      offset += 4;
      final data = bytes.sublist(offset, offset + length);
      offset += length + 4;

      final text = switch (type) {
        'tEXt' => _readTextChunk(data),
        'iTXt' => _readInternationalTextChunk(data),
        _ => null,
      };
      if (text != null && text.key == 'chara') {
        return text.value;
      }
    }

    return null;
  }

  bool _hasPngSignature(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  int _readUint32(Uint8List bytes, int offset) {
    return bytes.buffer.asByteData().getUint32(offset);
  }

  _PngText? _readTextChunk(Uint8List data) {
    final separator = data.indexOf(0);
    if (separator <= 0) return null;
    final key = latin1.decode(data.sublist(0, separator));
    final value = latin1.decode(data.sublist(separator + 1));
    return _PngText(key, value);
  }

  _PngText? _readInternationalTextChunk(Uint8List data) {
    final keywordEnd = data.indexOf(0);
    if (keywordEnd <= 0 || keywordEnd + 2 >= data.length) return null;
    final key = latin1.decode(data.sublist(0, keywordEnd));
    final compressionFlag = data[keywordEnd + 1];
    if (compressionFlag != 0) return null;

    var offset = keywordEnd + 3;
    final languageEnd = _indexOfZero(data, offset);
    if (languageEnd < 0) return null;
    offset = languageEnd + 1;

    final translatedKeywordEnd = _indexOfZero(data, offset);
    if (translatedKeywordEnd < 0) return null;
    offset = translatedKeywordEnd + 1;

    final value = utf8.decode(data.sublist(offset));
    return _PngText(key, value);
  }

  int _indexOfZero(Uint8List data, int start) {
    for (var i = start; i < data.length; i++) {
      if (data[i] == 0) return i;
    }
    return -1;
  }
}

class _PngText {
  final String key;
  final String value;

  const _PngText(this.key, this.value);
}
