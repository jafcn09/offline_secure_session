import 'dart:io';
import 'package:offline_secure_session/offline_secure_session.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => OfflineSecureSession.init(path: '${Directory.systemTemp.path}/test_oss', encryptionKey: 'my_secret_key_32_chars_long_xxx', maxQueueSize: 100));
  tearDown(() => OfflineSecureSession.reset());

  group('SecureSession', () {
    test('set/get token', () async { await OfflineSecureSession.session.set('jwt123'); expect(await OfflineSecureSession.session.get(), 'jwt123'); });
    test('token expires', () async { await OfflineSecureSession.session.set('x', exp: Duration.zero); await Future.delayed(Duration(milliseconds: 10)); expect(await OfflineSecureSession.session.get(), isNull); });
    test('clear token', () async { await OfflineSecureSession.session.set('del'); await OfflineSecureSession.session.clear(); expect(await OfflineSecureSession.session.get(), isNull); });
  });

  group('OfflineCache', () {
    test('set/get', () async { await OfflineSecureSession.cache.set('user', {'id': 1}); expect(await OfflineSecureSession.cache.get<Map>('user'), {'id': 1}); });
    test('remove', () async { await OfflineSecureSession.cache.set('tmp', 'val'); await OfflineSecureSession.cache.remove('tmp'); expect(await OfflineSecureSession.cache.get('tmp'), isNull); });
  });

  group('OfflineQueue', () {
    test('add/pending', () async { await OfflineSecureSession.queue.add({'a': 1}); await OfflineSecureSession.queue.add({'b': 2}); expect((await OfflineSecureSession.queue.pending).length, 2); });
    test('clear', () async { await OfflineSecureSession.queue.add({'x': 1}); await OfflineSecureSession.queue.clear(); expect((await OfflineSecureSession.queue.pending).length, 0); });
    test('max queue limit', () async { for (var i = 0; i < 100; i++) await OfflineSecureSession.queue.add({'i': i}); final added = await OfflineSecureSession.queue.add({'overflow': true}); expect(added, false); });
  });

  group('OfflineSync', () {
    test('process success/fail', () async {
      final sync = OfflineSecureSession.sync();
      await OfflineSecureSession.queue.add({'ok': true});
      await OfflineSecureSession.queue.add({'ok': false});
      await sync.process((a) async => a['ok'] == true);
      expect((await OfflineSecureSession.queue.pending).length, 1);
    });

    test('timeout', () async {
      final sync = OfflineSecureSession.sync(timeout: Duration(seconds: 2));
      await OfflineSecureSession.queue.clear();
      await OfflineSecureSession.queue.add({'id': 1});
      final t = DateTime.now();
      await sync.process((a) => Future.delayed(Duration(seconds: 5), () => true));
      expect(DateTime.now().difference(t).inSeconds, lessThanOrEqualTo(5));
    });

    test('retry with backoff', () async {
      final sync = OfflineSecureSession.sync(maxRetries: 3);
      await OfflineSecureSession.queue.clear();
      await OfflineSecureSession.queue.add({'fail': true});
      await sync.process((a) async => false);
      final q = await OfflineSecureSession.queue.pending;
      expect(q.length, 1);
      expect(q[0]['r'], 1);
    });

    test('onError callback', () async {
      final sync = OfflineSecureSession.sync(maxRetries: 1);
      await OfflineSecureSession.queue.clear();
      await OfflineSecureSession.queue.add({'myid': 'fail_item'});
      Map<String, dynamic>? failedAction;
      sync.onError = (a, e) => failedAction = a;
      await sync.process((a) async => false);
      await sync.process((a) async => false);
      expect(failedAction?['myid'], 'fail_item');
    });

    test('custom host', () async {
      final sync = OfflineSecureSession.sync(host: 'cloudflare.com');
      expect(sync.host, 'cloudflare.com');
    });
  });

  group('Encryption', () {
    test('data is encrypted on disk', () async {
      final path = '${Directory.systemTemp.path}/test_enc';
      OfflineSecureSession.init(path: path, encryptionKey: 'test_key_12345678901234567890xx');
      await OfflineSecureSession.session.set('secret_token');
      final raw = await File('${path}_session.dat').readAsString();
      expect(raw.contains('secret_token'), false);
      OfflineSecureSession.reset();
    });
  });

  group('Metrics', () {
    test('tracks operations', () async {
      await OfflineSecureSession.session.set('test');
      await OfflineSecureSession.cache.set('key', 'value');
      final m = OfflineSecureSession.metrics;
      expect(m['ops'], greaterThan(0));
    });
  });
}
