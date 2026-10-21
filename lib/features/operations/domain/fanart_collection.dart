class FanartCollection {
  const FanartCollection({
    required this.id,
    required this.title,
    required this.dates,
    required this.venue,
    required this.sourceUrl,
    required this.sourceAuthor,
    required this.groups,
    required this.entries,
  });

  final String id;
  final String title;
  final String dates;
  final String venue;
  final Uri sourceUrl;
  final String sourceAuthor;
  final List<String> groups;
  final List<FanartCollectionEntry> entries;

  List<FanartCollectionEntry> filteredEntries({
    String group = '',
    String query = '',
  }) {
    final words = query.trim().toLowerCase().split(RegExp(r'\s+'));
    return entries.where((entry) {
      final text =
          '${entry.title} ${entry.author} ${entry.summary} ${entry.groups.join(' ')}'
              .toLowerCase();
      return (group.isEmpty || entry.groups.contains(group)) &&
          words.every(text.contains);
    }).toList();
  }
}

class FanartCollectionEntry {
  const FanartCollectionEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    required this.authorUid,
    required this.sourceUrl,
    required this.groups,
    required this.images,
    required this.previews,
    required this.isVideo,
  });

  final String id;
  final String title;
  final String summary;
  final String author;
  final String? authorUid;
  final Uri sourceUrl;
  final List<String> groups;
  final List<Uri> images;
  final List<FanartCollectionPreview> previews;
  final bool isVideo;

  /// A group's showcase leads; original post images remain available.
  List<Uri> galleryImages(String group) => {
    for (final image in previews)
      if (group.isEmpty || image.groups.contains(group)) image.url,
    ...images,
    for (final image in previews) image.url,
  }.toList();
}

class FanartCollectionPreview {
  const FanartCollectionPreview({required this.url, required this.groups});

  final Uri url;
  final List<String> groups;
}
