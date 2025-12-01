import 'dart:async';
import 'dart:convert';
import 'dart:io';

class _Store {
  static final _f = File('${Directory.systemTemp.path}/offline.json');
  static Map<String, dynamic> _d = {};
  static Future<void> load() async => _d = _f.existsSync() ? jsonDecode(await _f.readAsString()) : {};
  static Future<void> save() async => await _f.writeAsString(jsonEncode(_d));
  static T? read<T>(String k) => _d[k] as T?;
  static void write(String k, dynamic v) => _d[k] = v;
  static void remove(String k) => _d.remove(k);
  static void clear() { _d.clear(); if (_f.existsSync()) _f.deleteSync(); }
}

class SecureSession {
  Future<void> set(String t, {Duration exp = const Duration(hours: 24)}) async { await _Store.load(); _Store.write('tk', base64Encode(utf8.encode(t))); _Store.write('ex', DateTime.now().add(exp).millisecondsSinceEpoch); await _Store.save(); }
  Future<String?> get() async { await _Store.load(); if ((_Store.read<int>('ex') ?? 0) < DateTime.now().millisecondsSinceEpoch) { await clear(); return null; } final t = _Store.read<String>('tk'); return t != null ? utf8.decode(base64Decode(t)) : null; }
  Future<void> clear() async { await _Store.load(); _Store.remove('tk'); _Store.remove('ex'); await _Store.save(); }
}

class OfflineCache {
  Future<void> set(String k, dynamic v) async { await _Store.load(); _Store.write('c_$k', v); await _Store.save(); }
  Future<T?> get<T>(String k) async { await _Store.load(); return _Store.read<T>('c_$k'); }
  Future<void> remove(String k) async { await _Store.load(); _Store.remove('c_$k'); await _Store.save(); }
}

class OfflineQueue {
  Future<void> add(Map<String, dynamic> a) async { await _Store.load(); (_Store.read<List>('q') ?? (_Store.write('q', <dynamic>[]) as List? ?? _Store.read<List>('q')!)).add({...a, 't': DateTime.now().millisecondsSinceEpoch}); await _Store.save(); }
  Future<List<Map<String, dynamic>>> get pending async { await _Store.load(); return List<Map<String, dynamic>>.from(_Store.read<List>('q') ?? []); }
  Future<void> clear() async { await _Store.load(); _Store.remove('q'); await _Store.save(); }
}

class OfflineSync {
  Timer? _t;
  void Function()? onOnline;
  final OfflineQueue _q = OfflineQueue();
  Future<void> process(Future<bool> Function(Map<String, dynamic>) fn) async {
    final q = await _q.pending, fail = <Map<String, dynamic>>[];
    for (final a in q) { if (!(await fn(a).timeout(const Duration(seconds: 2), onTimeout: () => false))) fail.add(a); }
    await _Store.load(); _Store.write('q', fail); await _Store.save();
  }
  void startMonitor() => _t ??= Timer.periodic(const Duration(seconds: 5), (_) async { try { if ((await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 1))).isNotEmpty) onOnline?.call(); } catch (_) {} });
  void stopMonitor() => _t?.cancel();
  static void reset() => _Store.clear();
}
