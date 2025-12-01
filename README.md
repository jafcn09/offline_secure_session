# Offline Secure Session

[![pub package](https://img.shields.io/pub/v/offline_secure_session.svg)](https://pub.dev/packages/offline_secure_session)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Enterprise-grade** Dart library for secure session management with AES-256 encryption and offline support.

Libreria Dart **nivel empresarial** para manejo seguro de sesiones con cifrado AES-256 y soporte offline.

---

## Features / Caracteristicas

| Feature | Description / Descripcion |
|---------|---------------------------|
| AES-256 Encryption | Real encryption with random IV / Cifrado real con IV aleatorio |
| GZIP Compression | Optimized storage / Almacenamiento optimizado |
| Thread-Safe | Lock mechanism for concurrent access / Mecanismo de bloqueo para acceso concurrente |
| Metrics | Operation tracking and performance stats / Seguimiento de operaciones y estadisticas |
| Logger Hook | Enterprise monitoring integration / Integracion con monitoreo empresarial |
| Retry with Backoff | Exponential backoff (1s, 2s, 4s... max 30s) / Reintento exponencial |

| Class | Purpose / Proposito |
|-------|---------------------|
| `SecureSession` | Token storage with expiration / Almacenamiento de token con expiracion |
| `OfflineCache` | Key-value persistent storage / Almacenamiento persistente clave-valor |
| `OfflineQueue` | Queue actions when offline / Encolar acciones sin conexion |
| `OfflineSync` | Process queue on reconnection / Procesar cola al reconectar |

---

## Installation / Instalacion

```yaml
dependencies:
  offline_secure_session: ^2.0.0
```

```bash
dart pub get
```

---

## Quick Start / Inicio Rapido

```dart
import 'package:offline_secure_session/offline_secure_session.dart';

void main() async {
  OfflineSecureSession.init(
    path: '/path/to/storage',
    encryptionKey: 'my_secret_key_32_chars_long_xxx',
    maxQueueSize: 10000,
  );

  await OfflineSecureSession.session.set('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  final token = await OfflineSecureSession.session.get();

  await OfflineSecureSession.cache.set('user', {'id': 1, 'name': 'John'});
  final user = await OfflineSecureSession.cache.get<Map>('user');

  await OfflineSecureSession.queue.add({'method': 'POST', 'url': '/api/orders', 'body': {'product': 'A1'}});

  final sync = OfflineSecureSession.sync(maxRetries: 5, timeout: Duration(seconds: 2));
  sync.onOnline = () => sync.process((action) async => true);
  sync.startMonitor();
}
```

---

## Enterprise Features / Funcionalidades Empresariales

### Logger Integration / Integracion de Logger

```dart
OfflineSecureSession.setLogger((level, message, data) {
  print('[$level] $message ${data ?? ''}');
});
```

### Metrics / Metricas

```dart
final metrics = OfflineSecureSession.metrics;
print('Operations: ${metrics['ops']}');
print('Errors: ${metrics['errors']}');
print('Queue size: ${metrics['queue']}');
print('Avg response: ${metrics['avg_ms']}ms');
```

### Custom Sync Configuration / Configuracion de Sync Personalizada

```dart
final sync = OfflineSecureSession.sync(
  host: 'your-api.com',
  maxRetries: 5,
  timeout: Duration(seconds: 2),
);

sync.onSuccess = (action) => print('Synced: $action');
sync.onError = (action, error) => print('Failed: $action - $error');
```

---

## Real World Example / Ejemplo Real

### E-commerce App

```dart
class OrderService {
  OrderService() {
    OfflineSecureSession.init(
      path: '/data/app',
      encryptionKey: 'your_32_char_encryption_key_here',
    );

    final sync = OfflineSecureSession.sync();
    sync.onOnline = _syncOrders;
    sync.startMonitor();
  }

  Future<void> placeOrder(Map<String, dynamic> order) async {
    await OfflineSecureSession.queue.add({
      'url': 'https://api.mystore.com/orders',
      'body': order,
      'token': await OfflineSecureSession.session.get(),
    });
  }

  Future<void> _syncOrders() async {
    final sync = OfflineSecureSession.sync();
    await sync.process((action) async {
      try {
        final response = await http.post(
          Uri.parse(action['url']),
          headers: {'Authorization': 'Bearer ${action['token']}'},
          body: jsonEncode(action['body']),
        );
        return response.statusCode == 201;
      } catch (_) {
        return false;
      }
    });
  }
}
```

### Login Flow / Flujo de Login

```dart
class AuthService {
  Future<void> login(String email, String password) async {
    final response = await http.post(...);
    final data = jsonDecode(response.body);

    await OfflineSecureSession.session.set(data['token'], exp: Duration(hours: 8));
    await OfflineSecureSession.cache.set('profile', data['user']);
  }

  Future<bool> get isLoggedIn async => await OfflineSecureSession.session.get() != null;

  Future<void> logout() async {
    await OfflineSecureSession.session.clear();
    await OfflineSecureSession.cache.remove('profile');
  }
}
```

---

## API Reference / Referencia API

### OfflineSecureSession

| Method | Description / Descripcion |
|--------|---------------------------|
| `init(path, encryptionKey, maxQueueSize)` | Initialize library / Inicializar libreria |
| `session` | Access SecureSession / Acceder a SecureSession |
| `cache` | Access OfflineCache / Acceder a OfflineCache |
| `queue` | Access OfflineQueue / Acceder a OfflineQueue |
| `sync(...)` | Create OfflineSync instance / Crear instancia de OfflineSync |
| `metrics` | Get operation metrics / Obtener metricas |
| `setLogger(handler)` | Set logger callback / Establecer callback de logger |
| `reset()` | Clear all data / Limpiar todos los datos |

### SecureSession

| Method | Description / Descripcion |
|--------|---------------------------|
| `set(token, {exp})` | Save token with expiration / Guardar token con expiracion |
| `get()` | Get token (null if expired) / Obtener token (null si expiro) |
| `clear()` | Clear token / Limpiar token |

### OfflineCache

| Method | Description / Descripcion |
|--------|---------------------------|
| `set(key, value)` | Save any value / Guardar cualquier valor |
| `get<T>(key)` | Get typed value / Obtener valor tipado |
| `remove(key)` | Remove key / Eliminar clave |

### OfflineQueue

| Method | Description / Descripcion |
|--------|---------------------------|
| `add(action)` | Queue action (returns false if full) / Encolar accion (false si llena) |
| `pending` | Get pending list / Obtener lista pendiente |
| `clear()` | Clear queue / Limpiar cola |

### OfflineSync

| Method | Description / Descripcion |
|--------|---------------------------|
| `onOnline` | Reconnection callback / Callback de reconexion |
| `onSuccess` | Success callback / Callback de exito |
| `onError` | Error callback / Callback de error |
| `startMonitor()` | Start connectivity monitor / Iniciar monitor |
| `stopMonitor()` | Stop monitor / Detener monitor |
| `process(handler)` | Process queue with timeout / Procesar cola con timeout |

---

## Architecture / Arquitectura

```
OfflineSecureSession.init()
          |
    _Crypto (AES-256 + GZIP)
          |
    _Store (Thread-safe persistence)
          |
    +-----+-----+-----+-----+
    |     |     |     |     |
Session Cache Queue  Sync  Metrics
```

---

## Security / Seguridad

- AES-256 encryption with random IV per operation
- SHA-256 key derivation
- GZIP compression before encryption
- Separate encrypted files for session, cache, and queue
- Thread-safe operations with lock mechanism

---

## Compatibility / Compatibilidad

| Dart SDK | Status |
|----------|--------|
| >= 2.17.0 | Supported |
| < 4.0.0 | Supported |

---

## License / Licencia

MIT License - see [LICENSE](LICENSE)