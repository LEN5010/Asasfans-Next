import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/asasfans_app.dart';
import 'app/glass_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Asasfans Next',
    ], await rootBundle.loadString('LICENSE'));
    yield LicenseEntryWithLineBreaks([
      'LoveIwara glass integration',
    ], await rootBundle.loadString('third_party/LoveIwara-LICENSE'));
  });
  runApp(
    ProviderScope(
      overrides: [observeGlassRendererErrors()],
      child: const AsasfansApp(),
    ),
  );
}
