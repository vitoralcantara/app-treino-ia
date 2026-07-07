import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  Future<ProcessedDocument> processFile(dynamic file) async {
    String fileName;
    String extension;
    Uint8List bytes;

    if (!kIsWeb && file is io.File) {
      fileName = p.basename(file.path);
      extension = p.extension(file.path).toLowerCase();
      bytes = await file.readAsBytes();
    } else if (file is Map<String, dynamic> && file.containsKey('bytes') && file.containsKey('name')) {
      // Formato customizado para web
      fileName = file['name'];
      extension = p.extension(fileName).toLowerCase();
      bytes = file['bytes'];
    } else {
      throw Exception('Tipo de arquivo não suportado ou plataforma incompatível.');
    }

    try {
      if (extension == '.pdf') {
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.pdf,
          bytes: bytes,
        );
      } else if (extension == '.docx') {
        final text = docxToText(bytes);
        return ProcessedDocument(
          fileName: fileName,
          type: DocumentType.docx,
          textContent: text,
        );
      } else if (extension == '.xlsx' || extension == '.xls') {
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
        final text = utf8.decode(bytes);
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
