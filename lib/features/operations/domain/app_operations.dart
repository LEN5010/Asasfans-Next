import '../../release/domain/app_release.dart';

class OperationAction {
  const OperationAction(this.type, this.value);
  final String type;
  final String value;

  factory OperationAction.fromJson(Map<String, dynamic> json) =>
      OperationAction(json['type'] as String, json['value'] as String);
}

/// Campaigns and announcements share their schedule and navigation fields.
class AppOperation {
  const AppOperation({
    required this.id,
    required this.title,
    required this.body,
    required this.startsAt,
    required this.endsAt,
    this.enabled = true,
    this.action,
    this.buttonLabel = '',
    this.bannerImage,
    this.splashImage,
    this.splashEnabled = false,
    this.important = false,
  });
  final String id, title, body, buttonLabel;
  final DateTime startsAt, endsAt;
  final bool enabled, splashEnabled, important;
  final Uri? bannerImage, splashImage;
  final OperationAction? action;

  bool activeAt(DateTime now) =>
      enabled && !now.isBefore(startsAt) && now.isBefore(endsAt);

  factory AppOperation.fromJson(Map<String, dynamic> json) => AppOperation(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    enabled: json['enabled'] == true,
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    action: json['action'] == null
        ? null
        : OperationAction.fromJson(json['action'] as Map<String, dynamic>),
    buttonLabel: json['buttonLabel'] as String? ?? '',
    bannerImage: operationHttps(json['bannerImageUrl']),
    splashImage: operationHttps(json['splashImageUrl']),
    splashEnabled: json['splashEnabled'] == true,
    important: json['important'] == true,
  );
}

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.platform,
    this.recommendedVersion,
    this.minimumVersion,
    this.message = '',
    this.enabled = true,
  });
  final String platform, message;
  final AppVersion? recommendedVersion, minimumVersion;
  final bool enabled;

  bool requires(AppVersion current) =>
      enabled &&
      minimumVersion != null &&
      current.compareTo(minimumVersion!) < 0;
  bool recommends(AppVersion current) =>
      enabled &&
      recommendedVersion != null &&
      current.compareTo(recommendedVersion!) < 0;

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) =>
      AppUpdatePolicy(
        platform: json['platform'] as String,
        enabled: json['enabled'] == true,
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
