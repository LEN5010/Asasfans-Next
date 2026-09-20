import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalLinkService {
  Future<bool> open(Uri uri);
}

class SystemExternalLinkService implements ExternalLinkService {
  const SystemExternalLinkService();

  @override
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
