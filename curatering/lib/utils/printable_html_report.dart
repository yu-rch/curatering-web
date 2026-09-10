/// Builds a self-contained HTML report suitable for browser print / Save as PDF.
///
/// Buttons use element ids (no inline JS). [openHtmlDocument] wires print/close
/// from the opener so CSP without `'unsafe-inline'` still works.
String buildPrintableHtmlReport({
  required String title,
  required String subtitle,
  required List<PrintableHtmlSection> sections,
  bool autoPrint = true,
}) {
  final buf = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('<title>${_esc(title)}</title>')
    ..writeln('<style>')
    ..writeln('''
      :root { color-scheme: light; }
      body {
        margin: 24px;
        font-family: "Segoe UI", Tahoma, sans-serif;
        color: #1f1f1f;
        background: #fff;
      }
      h1 { font-size: 22px; margin: 0 0 4px; }
      .sub { color: #595959; font-size: 13px; margin-bottom: 20px; }
      h2 { font-size: 15px; margin: 20px 0 8px; }
      table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 8px;
        font-size: 12px;
      }
      th, td {
        border: 1px solid #d9d9d9;
        padding: 6px 8px;
        text-align: left;
        vertical-align: top;
      }
      th { background: #f0f0f0; font-weight: 600; }
      .toolbar {
        position: sticky;
        top: 0;
        z-index: 1;
        display: flex;
        gap: 8px;
        align-items: center;
        padding: 10px 0 14px;
        margin-bottom: 8px;
        background: #fff;
        border-bottom: 1px solid #f0f0f0;
      }
      button {
        border: 1px solid #1677ff;
        background: #1677ff;
        color: #fff;
        border-radius: 6px;
        padding: 8px 14px;
        font-size: 13px;
        cursor: pointer;
      }
      button.secondary {
        background: #fff;
        color: #1677ff;
      }
      @media print {
        .toolbar { display: none !important; }
        body { margin: 12px; }
      }
      @page { size: landscape; margin: 12mm; }
    ''')
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<div class="toolbar">')
    ..writeln(
      '<button type="button" id="print-btn">Print / Save as PDF</button>',
    )
    ..writeln(
      '<button type="button" class="secondary" id="close-btn">Close</button>',
    )
    ..writeln(
      '<span class="sub">Use your browser print dialog to save a PDF.</span>',
    )
    ..writeln('</div>')
    ..writeln('<h1>${_esc(title)}</h1>')
    ..writeln('<div class="sub">${_esc(subtitle)}</div>');

  for (final section in sections) {
    buf.writeln('<h2>${_esc(section.title)}</h2>');
    buf.writeln('<table><thead><tr>');
    for (final h in section.headers) {
      buf.writeln('<th>${_esc(h)}</th>');
    }
    buf.writeln('</tr></thead><tbody>');
    for (final row in section.rows) {
      buf.writeln('<tr>');
      for (final cell in row) {
        buf.writeln('<td>${_esc(cell)}</td>');
      }
      buf.writeln('</tr>');
    }
    buf.writeln('</tbody></table>');
  }

  // autoPrint is handled by openHtmlDocument (CSP-safe), not inline script.
  buf
    ..writeln('</body>')
    ..writeln('</html>');
  return buf.toString();
}

/// Image-based print preview (seating / theme) — same toolbar UX as tables.
String buildPrintableHtmlImageReport({
  required String title,
  required String subtitle,
  required String imageMime,
  required String imageBase64,
  bool autoPrint = true,
}) {
  final buf = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln('<title>${_esc(title)}</title>')
    ..writeln('<style>')
    ..writeln('''
      body { margin: 24px; font-family: "Segoe UI", Tahoma, sans-serif; color: #1f1f1f; }
      h1 { font-size: 20px; margin: 0 0 4px; }
      .sub { color: #595959; font-size: 13px; margin-bottom: 16px; }
      .toolbar { display: flex; gap: 8px; align-items: center; padding-bottom: 12px; margin-bottom: 8px; border-bottom: 1px solid #f0f0f0; }
      button { border: 1px solid #1677ff; background: #1677ff; color: #fff; border-radius: 6px; padding: 8px 14px; font-size: 13px; cursor: pointer; }
      button.secondary { background: #fff; color: #1677ff; }
      img.preview { max-width: 100%; max-height: 80vh; object-fit: contain; display: block; margin: 0 auto; }
      @media print { .toolbar { display: none !important; } }
      @page { size: landscape; margin: 10mm; }
    ''')
    ..writeln('</style></head><body>')
    ..writeln('<div class="toolbar">')
    ..writeln(
      '<button type="button" id="print-btn">Print / Save as PDF</button>',
    )
    ..writeln(
      '<button type="button" class="secondary" id="close-btn">Close</button>',
    )
    ..writeln('</div>')
    ..writeln('<h1>${_esc(title)}</h1>')
    ..writeln('<div class="sub">${_esc(subtitle)}</div>')
    ..writeln(
      '<img class="preview" alt="${_esc(title)}" src="data:$imageMime;base64,$imageBase64">',
    )
    ..writeln('</body></html>');
  return buf.toString();
}

class PrintableHtmlSection {
  const PrintableHtmlSection({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
