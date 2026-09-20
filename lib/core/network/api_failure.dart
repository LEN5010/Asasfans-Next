enum ApiFailureKind {
  offline,
  timeout,
  invalidRequest,
  datasetChanged,
  rateLimited,
  unavailable,
  invalidResponse,
  cancelled,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.retryAfter, this.code});

  final ApiFailureKind kind;
  final Duration? retryAfter;

  /// Server-supplied discriminator, kept so a snapshot change and a video
  /// metrics change stay distinguishable in diagnostics even though both
  /// recover by dropping the cursor and reloading the first page.
  final String? code;

  String get message => switch (kind) {
    ApiFailureKind.offline => '网络连接失败',
    ApiFailureKind.timeout => '连接超时，请重试',
    ApiFailureKind.invalidRequest => '请求无效，请重新选择',
    ApiFailureKind.datasetChanged => '内容已更新，请刷新',
    ApiFailureKind.rateLimited => '请求较多，请稍后再试',
    ApiFailureKind.unavailable => '服务暂时不可用',
    ApiFailureKind.invalidResponse => '内容加载失败',
    ApiFailureKind.cancelled => '已取消',
  };

  @override
  String toString() =>
      'ApiFailure(${kind.name}${code == null ? '' : ', $code'})';
}
