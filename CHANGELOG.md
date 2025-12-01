# Changelog

## 2.0.0

### Breaking Changes
- Now requires `init()` before using any component
- Encryption key is now required

### Added
- AES-256 encryption with random IV per operation
- SHA-256 key derivation
- GZIP compression for optimized storage
- Thread-safe operations with lock mechanism
- Logger hook for enterprise monitoring
- Metrics tracking (operations, errors, queue size, avg response time)
- Exponential backoff retry (1s, 2s, 4s... max 30s)
- Configurable max queue size
- `onSuccess` and `onError` callbacks in OfflineSync
- Configurable connectivity check host

### Changed
- Separate encrypted files for session, cache, and queue
- SDK requirement updated to >=2.17.0

### Dependencies
- Added `crypto: ^3.0.3`
- Added `encrypt: ^5.0.3`

---

## 1.0.0

### Added
- `SecureSession` - Token storage with expiration
- `OfflineCache` - Key-value persistent storage
- `OfflineQueue` - Queue actions when offline
- `OfflineSync` - Process queue on reconnection with 2s timeout

### Features
- Single file architecture
- Compatible with Dart SDK >=2.12.0 <4.0.0
- Automatic connectivity monitoring