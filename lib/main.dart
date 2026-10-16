import 'package:flutter/material.dart';

import 'entry_io.dart' if (dart.library.js_interop) 'entry_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(buildRootApp());
}
