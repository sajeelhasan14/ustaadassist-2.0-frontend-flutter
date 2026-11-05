import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a finished file to the teacher.
///
/// In a browser that means a normal download. On a phone it opens the share
/// sheet, because that one step covers everything a teacher does next: save it,
/// open it in a viewer, print it, or send it on WhatsApp.
Future<void> saveFile(Uint8List bytes, String fileName) async {
  final isPdf = fileName.endsWith('.pdf');
  final mime = isPdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (kIsWeb) {
    await FileSaver.instance.saveFile(
      name: fileName.substring(0, fileName.lastIndexOf('.')),
      bytes: bytes,
      fileExtension: isPdf ? 'pdf' : 'xlsx',
      mimeType: MimeType.custom,
      customMimeType: mime,
    );
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: [fileName]),
  );
}
