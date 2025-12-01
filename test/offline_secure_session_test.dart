import 'package:offline_secure_session/offline_secure_session.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => OfflineSync.reset());

  group('SecureSession', () {
    final s = SecureSession();
    test('set/get token', () async { await s.set('jwt123'); expect(await s.get(), 'jwt123'); });
    test('token expires', () async { await s.set('x', exp: Duration.zero); await Future.delayed(Duration(milliseconds: 5)); expect(await s.get(), isNull); });
    test('clear token', () async { await s.set('del'); await s.clear(); expect(await s.get(), isNull); });
  });

  group('OfflineCache', () {
    final c = OfflineCache();
    test('set/get', () async { await c.set('user', {'id': 1}); expect(await c.get<Map>('user'), {'id': 1}); });
    test('remove', () async { await c.set('tmp', 'val'); await c.remove('tmp'); expect(await c.get('tmp'), isNull); });
  });

  group('OfflineQueue', () {
    final q = OfflineQueue();
    test('add/pending', () async { await q.add({'a': 1}); await q.add({'b': 2}); expect((await q.pending).length, 2); });
    test('clear', () async { await q.add({'x': 1}); await q.clear(); expect((await q.pending).length, 0); });
  });

  group('OfflineSync', () {
    final sync = OfflineSync();
    final q = OfflineQueue();
    test('process success/fail', () async { await q.add({'ok': true}); await q.add({'ok': false}); await sync.process((a) async => a['ok'] == true); expect((await q.pending).length, 1); });
    test('timeout 2s', () async {
      await q.clear(); await q.add({'id': 1});
      final t = DateTime.now();
      await sync.process((a) => Future.delayed(Duration(seconds: 5), () => true));
      expect(DateTime.now().difference(t).inSeconds, lessThanOrEqualTo(3));
    });
  });
}
