import '../../release/domain/app_release.dart';

class OperationAction {
  const OperationAction(this.type, this.value);
  final String type;
  final String value;

  factory OperationAction.fromJson(Map<String, dynamic> json) =>
      OperationAction(json['type'] as String, json['value'] as String);
}

/// An uploaded poster with the size it was converted to.
class OperationImage {
  const OperationImage(this.url, this.width, this.height);
  final Uri url;
  final int width, height;

  double get aspectRatio => width / height;

  static OperationImage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = operationHttps(json['url']);
    final width = json['width'], height = json['height'];
    return url != null &&
            width is int &&
            height is int &&
            width > 0 &&
            height > 0
        ? OperationImage(url, width, height)
        : null;
  }
}

/// A campaign's launch poster: one image for tall windows, one for wide.
class OperationSplash {
  const OperationSplash({this.portrait, this.landscape, this.seconds = 5});
  final OperationImage? portrait, landscape;
  final int seconds;

  /// The image drawn for the window's shape, or the other one when only
  /// one was uploaded.
  OperationImage? pick({required bool tall}) =>
      tall ? portrait ?? landscape : landscape ?? portrait;

  static OperationSplash? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final splash = OperationSplash(
      portrait: OperationImage.fromJson(json['portrait']),
      landscape: OperationImage.fromJson(json['landscape']),
      seconds: (json['seconds'] as int?) ?? 5,
    );
    return splash.portrait == null && splash.landscape == null ? null : splash;
  }
}

/// Campaigns and announcements share their schedule and navigation fields.
/// Everything served is published; the schedule alone decides when it shows.
class AppOperation {
  const AppOperation({
    required this.id,
    required this.title,
    required this.body,
    required this.startsAt,
    required this.endsAt,
    this.platforms = const [],
    this.action,
    this.buttonLabel = '',
    this.strip = false,
    this.splash,
    this.important = false,
    this.image,
  });
  final String id, title, body, buttonLabel;
  final DateTime startsAt, endsAt;

  /// Empty means every platform.
  final List<String> platforms;
  final bool strip, important;
  final OperationSplash? splash;
  final OperationImage? image;
  final OperationAction? action;

  bool activeAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);
  bool endedAt(DateTime now) => !now.isBefore(endsAt);
  bool availableOn(String platform) =>
      platforms.isEmpty || platforms.contains(platform);

  factory AppOperation.fromJson(Map<String, dynamic> json) => AppOperation(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    platforms: [for (final item in json['platforms'] as List) item as String],
    action: json['action'] == null
        ? null
        : OperationAction.fromJson(json['action'] as Map<String, dynamic>),
    buttonLabel: json['buttonLabel'] as String? ?? '',
    strip: json['strip'] == true,
    splash: OperationSplash.fromJson(json['splash']),
    important: json['important'] == true,
    image: OperationImage.fromJson(json['image']),
  );
}

/// A served policy is in force; withdrawing it removes it from the feed.
class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.platform,
    this.recommendedVersion,
    this.minimumVersion,
    this.message = '',
  });
  final String platform, message;
  final AppVersion? recommendedVersion, minimumVersion;

  bool requires(AppVersion current) =>
      minimumVersion != null && current.compareTo(minimumVersion!) < 0;
  bool recommends(AppVersion current) =>
      recommendedVersion != null && current.compareTo(recommendedVersion!) < 0;

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) =>
      AppUpdatePolicy(
        platform: json['platform'] as String,
        recommendedVersion: AppVersion.tryParse(
          json['recommendedVersion'] as String? ?? '',
        ),
        minimumVersion: AppVersion.tryParse(
          json['minimumVersion'] as String? ?? '',
        ),
        message: json['message'] as String? ?? '',
      );
}

class AppSupport {
  const AppSupport({required this.feedback, this.contact, this.help});
  final Uri feedback;
  final Uri? contact, help;

  static final defaults = AppSupport(
    feedback: Uri.parse('https://github.com/LEN5010/Asasfans-Next/issues'),
    contact: Uri.parse('https://space.bilibili.com/107261543'),
    help: Uri.parse('https://len5010.top/download'),
  );

  factory AppSupport.fromJson(Map<String, dynamic> json) => AppSupport(
    feedback: operationHttps(json['feedbackUrl']) ?? defaults.feedback,
    contact: operationHttps(json['contactUrl']),
    help: operationHttps(json['helpUrl']),
  );
}

class AppOperations {
  const AppOperations({
    this.campaigns = const [],
    this.announcements = const [],
    this.updates = const [],
    this.support,
  });
  final List<AppOperation> campaigns, announcements;
  final List<AppUpdatePolicy> updates;
  final AppSupport? support;

  factory AppOperations.fromJson(Map<String, dynamic> json) => AppOperations(
    campaigns: [
      for (final item in json['campaigns'] as List)
        AppOperation.fromJson(item as Map<String, dynamic>),
    ],
    announcements: [
      for (final item in json['announcements'] as List)
        AppOperation.fromJson(item as Map<String, dynamic>),
    ],
    updates: [
      for (final item in json['updates'] as List)
        AppUpdatePolicy.fromJson(item as Map<String, dynamic>),
    ],
    support: AppSupport.fromJson(json['support'] as Map<String, dynamic>),
  );
}

Uri? operationHttps(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}
