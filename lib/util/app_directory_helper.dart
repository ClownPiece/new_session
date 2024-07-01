import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppDirectoryHelper {
  AppDirectoryHelper._();
  static Directory? _directory;

  static Future<Directory> getAppDirectory() async {
    if (_directory != null) return _directory!;
    final appDocDirectory = await getApplicationDocumentsDirectory();
    _directory = appDocDirectory;

    return _directory!;
  }
}
