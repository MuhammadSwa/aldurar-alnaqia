import 'package:aldurar_alnaqia/common/helpers/file_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('bytes below 1 MB render as whole KB', () {
      expect(formatBytes(0), '0 KB');
      expect(formatBytes(512), '1 KB');
      expect(formatBytes(850 * 1024), '850 KB');
    });

    test('bytes at and above 1 MB render with one decimal', () {
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes((12.44 * 1024 * 1024).toInt()), '12.4 MB');
    });
  });
}
