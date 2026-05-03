import 'dart:io';

Future<bool> candidateImageLocalFileExists(String path) async {
  if (path.isEmpty) return false;
  return File(path).exists();
}
