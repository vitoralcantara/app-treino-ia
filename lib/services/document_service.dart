import 'dart:io';
import 'dart:typed_data';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

enum DocumentType { pdf, docx, xlsx, txt, unknown }

class ProcessedDocument {
  final String fileName;
  final DocumentType type;
  final String? textContent;
  final Uint8List? bytes;

  ProcessedDocument({
    required this.fileName,
    required this.type,
    this.textContent,
    this.bytes,
  });
}

class DocumentService {
  Future<ProcessedDocument> processFile(File file) async {
    final fileName = p.basename(file.path);
    final extension = p.extension(file.path).toLowerCase();

    try {
      if (extension == '.pdf') {
        final bytes = await file.readAsBytes();
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.pdf,
          bytes: bytes,
        );
      } else if (extension == '.docx') {
        final bytes = await file.readAsBytes();
        final text = docxToText(bytes);
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.docx,
          textContent: text,
        );
      } else if (extension == '.xlsx' || extension == '.xls') {
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        StringBuffer sb = StringBuffer();
        
        for (var table in excel.tables.keys) {
          sb.writeln('Planilha: $table');
          final sheet = excel.tables[table]!;
          for (var row in sheet.rows) {
            sb.writeln(row.map((cell) => cell?.value?.toString() ?? '').join(' | '));
          }
          sb.writeln();
        }
        
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.xlsx,
          textContent: sb.toString(),
        );
      } else if (extension == '.txt') {
        final text = await file.readAsString();
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.txt,
          textContent: text,
        );
      } else {
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.unknown,
        );
      }
    } catch (e) {
      throw Exception('Erro ao processar arquivo $fileName: $e');
    }
  }
}
