# Offline Secure Session

[![pub package](https://img.shields.io/pub/v/offline_secure_session.svg)](https://pub.dev/packages/offline_secure_session)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Zero-dependency** Dart library for secure session management with offline support.

Libreria Dart **sin dependencias** para manejo seguro de sesiones con soporte offline.

---

## Features / Caracteristicas

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
  offline_secure_session: ^1.0.0
```

```bash
dart pub get
```

---

## Quick Start / Inicio Rapido

```dart
import 'package:offline_secure_session/offline_secure_session.dart';

void main() async {
  final session = SecureSession();
  final cache = OfflineCache();
  final queue = OfflineQueue();
  final sync = OfflineSync();

  await session.set('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  final token = await session.get();

  await cache.set('user', {'id': 1, 'name': 'John'});
  final user = await cache.get<Map>('user');

  await queue.add({'method': 'POST', 'url': '/api/orders', 'body': {'product': 'A1'}});

  sync.onOnline = () => sync.process((action) async {
    return true;
  });
  sync.startMonitor();
}
```

---

## Real World Example / Ejemplo Real

### E-commerce App

```dart
class OrderService {
  final session = SecureSession();
  final queue = OfflineQueue();
  final sync = OfflineSync();

  OrderService() {
    sync.onOnline = _syncOrders;
    sync.startMonitor();
  }

  Future<void> placeOrder(Map<String, dynamic> order) async {
    await queue.add({
      'url': 'https://api.mystore.com/orders',
      'body': order,
      'token': await session.get(),
    });
  }

  Future<void> _syncOrders() async {
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
  final session = SecureSession();
  final cache = OfflineCache();

  Future<void> login(String email, String password) async {
    final response = await http.post(...);
    final data = jsonDecode(response.body);

    await session.set(data['token'], exp: Duration(hours: 8));
    await cache.set('profile', data['user']);
  }

  Future<bool> get isLoggedIn async => await session.get() != null;

  Future<void> logout() async {
    await session.clear();
    await cache.remove('profile');
  }
}
```

---

## API Reference / Referencia API

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
| `add(action)` | Queue action / Encolar accion |
| `pending` | Get pending list / Obtener lista pendiente |
| `clear()` | Clear queue / Limpiar cola |

### OfflineSync

| Method | Description / Descripcion |
|--------|---------------------------|
| `onOnline` | Reconnection callback / Callback de reconexion |
| `startMonitor()` | Start connectivity monitor / Iniciar monitor de conectividad |
| `stopMonitor()` | Stop monitor / Detener monitor |
| `process(handler)` | Process queue (2s timeout per action) / Procesar cola (2s timeout por accion) |
| `reset()` | Reset all stored data / Reiniciar todos los datos |

---

## Architecture / Arquitectura

```
                      _Store (internal)
                  Shared persistence layer
                            |
        +-------------------+-------------------+
        |         |         |                   |
  SecureSession  OfflineCache  OfflineQueue  OfflineSync
    Token+Exp     Key/Value     Actions       Process
```


## Compatibility / Compatibilidad

| Dart SDK | Status |
|----------|--------|
| >= 2.12.0 | Supported |
| < 4.0.0 | Supported |

---

## License / Licencia

MIT License - see [LICENSE](LICENSE)