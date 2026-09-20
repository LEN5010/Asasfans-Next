/// Serializes initialization and terminal shutdown of one login browser.
/// A failed shutdown is retryable; it must not be mistaken for a closed view.
class LoginBrowserLifecycle {
  bool _started = false;
  bool _closing = false;
  bool _closed = false;
  Future<void> _setup = Future.value();
  Future<void>? _shutdown;

  bool get acceptsNavigation => !_closing;
  bool get isClosed => _closed;

  Future<void> initialize(Future<void> Function() operation) {
    if (_started || _closing) return Future.value();
    _started = true;
    final setup = Future<void>.sync(operation);
    // Keep a settled barrier even if the caller handles an initialization
    // failure. Partial initialization still needs terminal cleanup.
    _setup = setup.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return setup;
  }

  Future<void> close(Future<void> Function() operation) {
    _closing = true;
    if (_closed) return Future.value();
    if (_shutdown != null) return _shutdown!;
    final work = _setup.then((_) async {
      await operation();
      _closed = true;
    });
    _shutdown = work.whenComplete(() => _shutdown = null);
    return _shutdown!;
  }

  Future<void> navigate(Future<void> Function() operation) {
    if (!_started || _closing) return Future.value();
    final work = _setup.then((_) async {
      if (!_closing) await operation();
    });
    _setup = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }
}
