enum StorageFailureKind {
  unavailable,
  incompatible,
  invalidData,
  closed,
  changed,
  capacity,
}

/// Public errors never include SQL, user content, file paths or credentials.
class StorageFailure implements Exception {
  const StorageFailure(this.kind);
  final StorageFailureKind kind;

  String get message => switch (kind) {
    StorageFailureKind.unavailable => '本地资料暂时无法读写，请重试',
    StorageFailureKind.incompatible => '本地资料版本不兼容，请更新应用',
    StorageFailureKind.invalidData => '本地资料无法读取',
    StorageFailureKind.closed => '本地资料已关闭，请重新打开应用',
    StorageFailureKind.changed => '资料已更新，请刷新列表',
    StorageFailureKind.capacity => '本地资料数量超过上限，请先整理',
  };

  @override
  String toString() => 'StorageFailure(${kind.name})';
}
