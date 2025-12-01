import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class _Crypto {
  static late enc.Key _key;
  static void setKey(String k) => _key = enc.Key.fromUtf8(sha256.convert(utf8.encode(k)).toString().substring(0, 32));
  static String encrypt(String data) { final iv = enc.IV.fromSecureRandom(16); return '${iv.base64}:${enc.Encrypter(enc.AES(_key)).encrypt(data, iv: iv).base64}'; }
  static String? decrypt(String data) { try { final p = data.split(':'); return enc.Encrypter(enc.AES(_key)).decrypt64(p[1], iv: enc.IV.fromBase64(p[0])); } catch (_) { return null; } }
}

class _Lock {
  final _q = <Completer<void>>[]; bool _l = false;
  Future<T> sync<T>(Future<T> Function() fn) async { final c = Completer<void>(); _q.add(c); if (_l) await c.future.timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException('Lock timeout')); _l = true; _q.remove(c); try { return await fn(); } finally { _l = false; if (_q.isNotEmpty) _q.first.complete(); } }
}

class _Store {
  final String path; final _lock = _Lock(); Map<String, dynamic> _d = {};
  _Store(this.path);
  Future<void> load() => _lock.sync(() async { final f = File(path); if (f.existsSync()) { final dec = _Crypto.decrypt(await f.readAsString()); if (dec != null) try { _d = jsonDecode(utf8.decode(gzip.decode(base64Decode(dec)))); } catch (_) { _d = {}; } } });
  Future<void> save() => _lock.sync(() async { final f = File(path); if (!f.parent.existsSync()) f.parent.createSync(recursive: true); await f.writeAsString(_Crypto.encrypt(base64Encode(gzip.encode(utf8.encode(jsonEncode(_d)))))); });
  T? read<T>(String k) => _d[k] as T?; void write(String k, dynamic v) => _d[k] = v; void remove(String k) => _d.remove(k);
  void clear() { _d.clear(); final f = File(path); if (f.existsSync()) f.deleteSync(); }
}

class _Log { static void Function(String, String, [Map<String, dynamic>?])? h; static void i(String m, [Map<String, dynamic>? d]) => h?.call('INFO', m, d); static void e(String m, [Map<String, dynamic>? d]) => h?.call('ERROR', m, d); }
class _Met { static int _o = 0, _e = 0, _q = 0; static final _t = <int>[]; static void op(int ms) { _o++; _t.add(ms); if (_t.length > 1000) _t.removeAt(0); } static void er() => _e++; static void qu(int s) => _q = s; static Map<String, dynamic> get s => {'ops': _o, 'errors': _e, 'queue': _q, 'avg_ms': _t.isEmpty ? 0 : _t.reduce((a, b) => a + b) ~/ _t.length}; }

class SecureSession {
  final _Store _s; SecureSession(this._s);
  Future<void> set(String t, {Duration exp = const Duration(hours: 24)}) async { final w = Stopwatch()..start(); await _s.load(); _s.write('tk', t); _s.write('ex', DateTime.now().add(exp).millisecondsSinceEpoch); await _s.save(); _Met.op(w.elapsedMilliseconds); _Log.i('Token set'); }
  Future<String?> get() async { await _s.load(); if ((_s.read<int>('ex') ?? 0) < DateTime.now().millisecondsSinceEpoch) { await clear(); return null; } return _s.read<String>('tk'); }
  Future<void> clear() async { await _s.load(); _s.remove('tk'); _s.remove('ex'); await _s.save(); }
}

class OfflineCache {
  final _Store _s; OfflineCache(this._s);
  Future<void> set(String k, dynamic v) async { final w = Stopwatch()..start(); await _s.load(); _s.write('c_$k', v); await _s.save(); _Met.op(w.elapsedMilliseconds); }
  Future<T?> get<T>(String k) async { await _s.load(); return _s.read<T>('c_$k'); }
  Future<void> remove(String k) async { await _s.load(); _s.remove('c_$k'); await _s.save(); }
}

class OfflineQueue {
  final _Store _s; final int max; OfflineQueue(this._s, {this.max = 10000});
  Future<bool> add(Map<String, dynamic> a) async { final w = Stopwatch()..start(); await _s.load(); final q = List<Map<String, dynamic>>.from(_s.read<List>('q') ?? []); if (q.length >= max) { _Log.e('Queue full'); return false; } q.add({...a, 't': DateTime.now().millisecondsSinceEpoch, 'r': 0, 'id': '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}'}); _s.write('q', q); await _s.save(); _Met.qu(q.length); _Met.op(w.elapsedMilliseconds); return true; }
  Future<List<Map<String, dynamic>>> get pending async { await _s.load(); return List<Map<String, dynamic>>.from(_s.read<List>('q') ?? []); }
  Future<void> clear() async { await _s.load(); _s.remove('q'); await _s.save(); _Met.qu(0); }
}

class OfflineSync {
  Timer? _t; void Function()? onOnline; void Function(Map<String, dynamic>, Object)? onError; void Function(Map<String, dynamic>)? onSuccess;
  final String host; final int maxRetries; final Duration timeout; final _Store _s; final OfflineQueue _q;
  OfflineSync(this._s, this._q, {this.host = 'dns.google', this.maxRetries = 5, this.timeout = const Duration(seconds: 2)});

  Future<void> process(Future<bool> Function(Map<String, dynamic>) fn) async {
    final q = await _q.pending, keep = <Map<String, dynamic>>[];
    for (final a in q) {
      final w = Stopwatch()..start();
      try {
        final ok = await fn(a).timeout(timeout, onTimeout: () => false);
        if (ok) { onSuccess?.call(a); } else { final r = (a['r'] as int? ?? 0) + 1; if (r < maxRetries) { await Future.delayed(Duration(milliseconds: min(1000 * pow(2, r).toInt(), 30000))); keep.add({...a, 'r': r}); } else { _Met.er(); onError?.call(a, 'Max retries'); } }
      } catch (e) { keep.add(a); _Met.er(); onError?.call(a, e); }
      _Met.op(w.elapsedMilliseconds);
    }
    await _s.load(); _s.write('q', keep); await _s.save(); _Met.qu(keep.length);
  }

  void startMonitor([Duration interval = const Duration(seconds: 10)]) => _t ??= Timer.periodic(interval, (_) async { try { if ((await InternetAddress.lookup(host).timeout(const Duration(seconds: 2))).isNotEmpty) onOnline?.call(); } catch (_) {} });
  void stopMonitor() { _t?.cancel(); _t = null; }
}

class OfflineSecureSession {
  static _Store? _ss, _cs, _qs; static SecureSession? _se; static OfflineCache? _ca; static OfflineQueue? _qu;

  static void init({required String path, required String encryptionKey, int maxQueueSize = 10000}) {
    _Crypto.setKey(encryptionKey); _ss = _Store('${path}_session.dat'); _cs = _Store('${path}_cache.dat'); _qs = _Store('${path}_queue.dat');
    _se = SecureSession(_ss!); _ca = OfflineCache(_cs!); _qu = OfflineQueue(_qs!, max: maxQueueSize);
  }

  static void setLogger(void Function(String, String, [Map<String, dynamic>?]) h) => _Log.h = h;
  static Map<String, dynamic> get metrics => _Met.s;
  static SecureSession get session { if (_se == null) throw StateError('Call init() first'); return _se!; }
  static OfflineCache get cache { if (_ca == null) throw StateError('Call init() first'); return _ca!; }
  static OfflineQueue get queue { if (_qu == null) throw StateError('Call init() first'); return _qu!; }
  static OfflineSync sync({String host = 'dns.google', int maxRetries = 5, Duration timeout = const Duration(seconds: 2)}) { if (_qs == null || _qu == null) throw StateError('Call init() first'); return OfflineSync(_qs!, _qu!, host: host, maxRetries: maxRetries, timeout: timeout); }
  static void reset() { _ss?.clear(); _cs?.clear(); _qs?.clear(); }
}
