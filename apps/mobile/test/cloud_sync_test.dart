import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/services/cloud_sync.dart';

void main() {
  test('CloudSync defaults to local-only', () {
    expect(CloudSync.enabled, isFalse);
    expect(CloudSync.instance.isReady, isFalse);
  });
}
