import 'dart:io';
import 'package:offline_secure_session/offline_secure_session.dart';

void main() async {
  OfflineSecureSession.init(
    path: '${Directory.systemTemp.path}/my_app',
    encryptionKey: 'my_secret_key_32_chars_long_xxx',
    maxQueueSize: 10000,
  );

  await OfflineSecureSession.session.set('eyJhbGciOiJIUzI1NiJ9.token', exp: Duration(hours: 8));
  final token = await OfflineSecureSession.session.get();
  print('Token: $token');

  await OfflineSecureSession.cache.set('user', {'id': 1, 'name': 'John'});
  final user = await OfflineSecureSession.cache.get<Map>('user');
  print('User: $user');

  await OfflineSecureSession.queue.add({'method': 'POST', 'url': '/api/orders', 'body': {'product': 'A1'}});
  final pending = await OfflineSecureSession.queue.pending;
  print('Pending actions: ${pending.length}');

  final sync = OfflineSecureSession.sync(maxRetries: 3, timeout: Duration(seconds: 2));
  sync.onSuccess = (action) => print('Synced: ${action['url']}');
  sync.onError = (action, error) => print('Failed: $error');
  await sync.process((action) async => true);

  final metrics = OfflineSecureSession.metrics;
  print('Metrics: $metrics');

  OfflineSecureSession.reset();
}