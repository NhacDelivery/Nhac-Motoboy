import 'api_config.dart';

/// Cache somente em memória: nunca persiste JWT, código ou endereço de corrida.
/// Invalida também respostas em voo quando a sessão ou a revisão muda.
class SessionQueryCache {
  SessionQueryCache({this.maximumSize = 80, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    ApiConfig.session.addListener(clear);
  }
  static final shared = SessionQueryCache();
  final int maximumSize;
  final DateTime Function() _clock;
  final _values = <String, ({Object value, DateTime expires})>{};
  final _pending = <String, Future<Object>>{};
  int _revision = 0;
  bool _disposed = false;

  T? peek<T extends Object>(String key) {
    final entry = _values.remove(key);
    if (entry == null) return null;
    if (!_clock().isBefore(entry.expires)) return null;
    _values[key] = entry;
    return entry.value as T;
  }

  Future<T> load<T extends Object>(
    String key,
    Duration ttl,
    Future<T> Function() fetch, {
    bool force = false,
  }) async {
    if (_disposed) throw StateError('Cache encerrado.');
    if (!force) {
      final value = peek<T>(key);
      if (value != null) return value;
    }
    final existing = _pending[key];
    if (existing != null) return await existing as T;
    final revision = _revision;
    final operation = Future<T>.sync(fetch);
    _pending[key] = operation;
    try {
      final result = await operation;
      if (!_disposed && revision == _revision) {
        _values.remove(key);
        _values[key] = (value: result, expires: _clock().add(ttl));
        while (_values.length > maximumSize) {
          _values.remove(_values.keys.first);
        }
      }
      return result;
    } finally {
      if (identical(_pending[key], operation)) _pending.remove(key);
    }
  }

  void clear() {
    _revision++;
    _values.clear();
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    ApiConfig.session.removeListener(clear);
    clear();
  }
}
