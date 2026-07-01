import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>();
  
  int updatedFiles = 0;
  for (final file in files) {
    if (file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      if (content.contains('GoogleFonts.audiowide')) {
        final newContent = content.replaceAll('GoogleFonts.audiowide', 'GoogleFonts.inter');
        file.writeAsStringSync(newContent);
        updatedFiles++;
        print('Updated \${file.path}');
      }
    }
  }
  print('Total updated: \$updatedFiles');
}
