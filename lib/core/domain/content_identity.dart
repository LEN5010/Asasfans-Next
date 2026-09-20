enum ContentSource { bilibiliVideo, bilibiliDynamic, doubanTopic }

/// A source item is not identified by its title or temporary media URL.
class ContentIdentity {
  const ContentIdentity({required this.source, required this.value});
  final ContentSource source;
  final String value;

  String get storageKey => '${source.name}:$value';

  @override
  bool operator ==(Object other) =>
      other is ContentIdentity &&
      other.source == source &&
      other.value == value;

  @override
  int get hashCode => Object.hash(source, value);
}
