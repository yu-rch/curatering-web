import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/website_header_font.dart';

class _MarkupState {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  double? fontSize;
  Color? color;
  String? linkUrl;
  String? fontFamily;

  _MarkupState clone() {
    return _MarkupState()
      ..bold = bold
      ..italic = italic
      ..underline = underline
      ..fontSize = fontSize
      ..color = color
      ..linkUrl = linkUrl
      ..fontFamily = fontFamily;
  }
}

final _markupExp = RegExp(
  r'\[(\/?)(b|i|u|size|color|link|font)(?:=([^\]]+))?\]',
);

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

String _stripHtmlAttributes(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _htmlToWebsiteMarkup(String html) {
  var text = html;
  text = text.replaceAll(RegExp(r'\r\n?'), '\n');
  text = text.replaceAllMapped(
    RegExp(
      r"""<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>""",
      caseSensitive: false,
      dotAll: true,
    ),
    (m) => '[link=${m.group(1) ?? ''}]${m.group(2) ?? ''}[/link]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r"""<span\b[^>]*style=["']([^"']+)["'][^>]*>(.*?)</span>""",
      caseSensitive: false,
      dotAll: true,
    ),
    (m) {
      final style = (m.group(1) ?? '').toLowerCase();
      var child = m.group(2) ?? '';
      final color = RegExp(r'color\s*:\s*([^;]+)').firstMatch(style)?.group(1);
      final size = RegExp(
        r'font-size\s*:\s*([0-9.]+)',
      ).firstMatch(style)?.group(1);
      final font = RegExp(
        r'font-family\s*:\s*([^;]+)',
      ).firstMatch(style)?.group(1);
      if (font != null && font.trim().isNotEmpty) {
        child =
            '[font=${_stripHtmlAttributes(font).replaceAll("'", '').replaceAll('"', '')}]$child[/font]';
      }
      if (size != null && size.trim().isNotEmpty) {
        child = '[size=$size]$child[/size]';
      }
      if (color != null && color.trim().isNotEmpty) {
        child = '[color=${_stripHtmlAttributes(color)}]$child[/color]';
      }
      return child;
    },
  );
  text = text
      .replaceAll(RegExp(r'<\s*(strong|b)\s*>', caseSensitive: false), '[b]')
      .replaceAll(
        RegExp(r'<\s*/\s*(strong|b)\s*>', caseSensitive: false),
        '[/b]',
      )
      .replaceAll(RegExp(r'<\s*(em|i)\s*>', caseSensitive: false), '[i]')
      .replaceAll(RegExp(r'<\s*/\s*(em|i)\s*>', caseSensitive: false), '[/i]')
      .replaceAll(RegExp(r'<\s*u\s*>', caseSensitive: false), '[u]')
      .replaceAll(RegExp(r'<\s*/\s*u\s*>', caseSensitive: false), '[/u]')
      .replaceAll(RegExp(r'<\s*h1[^>]*>', caseSensitive: false), '[b][size=42]')
      .replaceAll(
        RegExp(r'<\s*/\s*h1\s*>', caseSensitive: false),
        '[/size][/b]\n',
      )
      .replaceAll(RegExp(r'<\s*h2[^>]*>', caseSensitive: false), '[b][size=32]')
      .replaceAll(
        RegExp(r'<\s*/\s*h2\s*>', caseSensitive: false),
        '[/size][/b]\n',
      )
      .replaceAll(RegExp(r'<\s*h3[^>]*>', caseSensitive: false), '[b][size=24]')
      .replaceAll(
        RegExp(r'<\s*/\s*h3\s*>', caseSensitive: false),
        '[/size][/b]\n',
      )
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*/\s*(p|div)\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<\s*(p|div)[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*/?\s*(ul|ol)[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return _decodeHtmlEntities(text).trim();
}

Color? _parseMarkupColor(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  var hex = v.startsWith('#') ? v.substring(1) : v;
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length == 8) {
    final n = int.tryParse(hex, radix: 16);
    if (n != null) return Color(n);
  }
  return null;
}

TextStyle _activeStyle(TextStyle base, _MarkupState state) {
  var style = base;
  if (state.bold) {
    style = style.copyWith(fontWeight: FontWeight.w700);
  }
  if (state.italic) {
    style = style.copyWith(fontStyle: FontStyle.italic);
  }
  if (state.underline) {
    style = style.copyWith(decoration: TextDecoration.underline);
  }
  if (state.fontSize != null) {
    style = style.copyWith(fontSize: state.fontSize);
  }
  if (state.color != null) {
    style = style.copyWith(color: state.color);
  }
  if (state.linkUrl != null) {
    style = style.copyWith(
      color: const Color(0xFF1565C0),
      decoration: TextDecoration.underline,
    );
  }
  final family = state.fontFamily?.trim();
  if (family != null &&
      family.isNotEmpty &&
      family.toLowerCase() != 'default') {
    try {
      style = GoogleFonts.getFont(family, textStyle: style);
    } catch (_) {}
  }
  return style;
}

List<InlineSpan> buildWebsiteMarkupSpans(
  String text,
  TextStyle baseStyle, {
  List<TapGestureRecognizer>? recognizers,
}) {
  if (text.contains('<') && text.contains('>')) {
    text = _htmlToWebsiteMarkup(text);
  }
  final spans = <InlineSpan>[];
  final stack = [_MarkupState()];
  var cursor = 0;

  void appendText(String chunk) {
    if (chunk.isEmpty) return;
    final state = stack.last;
    final style = _activeStyle(baseStyle, state);
    final link = state.linkUrl?.trim();
    if (link != null && link.isNotEmpty) {
      final recognizer =
          TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(link);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            };
      recognizers?.add(recognizer);
      spans.add(TextSpan(text: chunk, style: style, recognizer: recognizer));
    } else {
      spans.add(TextSpan(text: chunk, style: style));
    }
  }

  void openTag(String tag, String? value) {
    final next = stack.last.clone();
    switch (tag) {
      case 'b':
        next.bold = true;
      case 'i':
        next.italic = true;
      case 'u':
        next.underline = true;
      case 'size':
        final size = double.tryParse(value ?? '');
        if (size != null) next.fontSize = size;
      case 'color':
        final c = _parseMarkupColor(value ?? '');
        if (c != null) next.color = c;
      case 'link':
        next.linkUrl = value?.trim();
      case 'font':
        next.fontFamily = value?.trim();
    }
    stack.add(next);
  }

  void closeTag(String tag) {
    if (stack.length <= 1) return;
    stack.removeLast();
  }

  for (final m in _markupExp.allMatches(text)) {
    if (m.start > cursor) {
      appendText(text.substring(cursor, m.start));
    }
    final closing = m.group(1) == '/';
    final tag = m.group(2)!;
    final value = m.group(3);
    if (closing) {
      closeTag(tag);
    } else {
      openTag(tag, value);
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    appendText(text.substring(cursor));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: baseStyle));
  }
  return spans;
}

/// Renders CMS rich text (`[b]`, `[size=18]`, `[color=#...]`, `[link=...]`, etc.).
class WebsiteRichText extends StatefulWidget {
  const WebsiteRichText({
    super.key,
    required this.value,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String value;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<WebsiteRichText> createState() => _WebsiteRichTextState();
}

class _WebsiteRichTextState extends State<WebsiteRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    return Text.rich(
      TextSpan(
        children: buildWebsiteMarkupSpans(
          widget.value,
          widget.style,
          recognizers: _recognizers,
        ),
      ),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

const _editorFontFamilies = <String>[
  'Default',
  'Scheherazade New',
  'Roboto',
  'Playfair Display',
  'Lato',
  'Open Sans',
  'Montserrat',
  'Merriweather',
  'Poppins',
  'Raleway',
  'Nunito',
  'Source Sans 3',
];

const _editorFontSizes = <double>[12, 14, 16, 18, 20, 24, 32, 42];

const _editorColors = <Color>[
  Color(0xFF1E1E1E),
  Color(0xFFB0305A),
  Color(0xFFD4380D),
  Color(0xFF389E0D),
  Color(0xFF1565C0),
  Color(0xFF722ED1),
  Color(0xFFFFC024),
];

/// Toolbar dialog for super-admin / live CMS HTML rich text fields.
Future<String?> showWebsiteRichTextEditor({
  required BuildContext context,
  required String title,
  required String initialValue,
}) async {
  return showDialog<String>(
    context: context,
    builder:
        (ctx) => _WebsiteRichTextEditorDialog(
          title: title,
          initialValue: initialValue,
        ),
  );
}

class _WebsiteRichTextEditorDialog extends StatefulWidget {
  const _WebsiteRichTextEditorDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final String initialValue;

  @override
  State<_WebsiteRichTextEditorDialog> createState() =>
      _WebsiteRichTextEditorDialogState();
}

class _WebsiteRichTextEditorDialogState
    extends State<_WebsiteRichTextEditorDialog> {
  late final TextEditingController _ctrl;
  double _previewSize = 16;
  String _previewFont = 'Default';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _wrap(String open, String close) {
    final sel = _ctrl.selection;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    if (start < 0 || end < 0) return;
    final text = _ctrl.text;
    final selected = start < end ? text.substring(start, end) : '';
    final replaced =
        '${text.substring(0, start)}$open$selected$close${text.substring(end)}';
    _ctrl.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(
        offset: start + open.length + selected.length + close.length,
      ),
    );
  }

  Future<void> _addLink() async {
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: const Text('Insert link'),
            content: TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, urlCtrl.text.trim()),
                child: const Text('Insert'),
              ),
            ],
          ),
    );
    urlCtrl.dispose();
    if (url == null || url.isEmpty) return;
    _wrap('<a href="$url">', '</a>');
  }

  Widget _toolbarButton({
    required String tooltip,
    required VoidCallback onPressed,
    Widget? child,
    IconData? icon,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child:
                child ??
                Icon(icon, size: 18, color: const Color(0xFF1E1E1E)),
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Wrap(
          spacing: 2,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _toolbarButton(
              tooltip: 'Bold',
              icon: Icons.format_bold,
              onPressed: () => _wrap('<strong>', '</strong>'),
            ),
            _toolbarButton(
              tooltip: 'Italic',
              icon: Icons.format_italic,
              onPressed: () => _wrap('<em>', '</em>'),
            ),
            _toolbarButton(
              tooltip: 'Underline',
              icon: Icons.format_underlined,
              onPressed: () => _wrap('<u>', '</u>'),
            ),
            _toolbarDivider(),
            _toolbarButton(
              tooltip: 'Paragraph',
              icon: Icons.notes,
              onPressed: () => _wrap('<p>', '</p>'),
            ),
            _toolbarButton(
              tooltip: 'Bullet list',
              icon: Icons.format_list_bulleted,
              onPressed: () => _wrap('<ul><li>', '</li></ul>'),
            ),
            _toolbarButton(
              tooltip: 'Insert link',
              icon: Icons.link,
              onPressed: _addLink,
            ),
            _toolbarDivider(),
            DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _previewSize,
                isDense: true,
                hint: const Text('Size', style: TextStyle(fontSize: 13)),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
                items: [
                  for (final s in _editorFontSizes)
                    DropdownMenuItem(
                      value: s,
                      child: Text('${s.toInt()}px'),
                    ),
                ],
                onChanged: (s) {
                  if (s == null) return;
                  setState(() => _previewSize = s);
                  _wrap(
                    '<span style="font-size:${s.toInt()}px">',
                    '</span>',
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _previewFont,
                isDense: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
                items: [
                  for (final f in _editorFontFamilies)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (f) {
                  if (f == null) return;
                  setState(() => _previewFont = f);
                  if (f == 'Default') return;
                  _wrap('<span style="font-family:$f">', '</span>');
                },
              ),
            ),
            PopupMenuButton<Color>(
              tooltip: 'Text color',
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette_outlined, size: 18, color: Colors.grey.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'Color',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              itemBuilder:
                  (ctx) => [
                    for (final c in _editorColors)
                      PopupMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
              onSelected: (c) {
                final hex =
                    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
                _wrap('<span style="color:$hex">', '</span>');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'HTML',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey.shade700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '<p>Select text, then use the toolbar to format.</p>',
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Live preview',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey.shade700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              child: WebsiteRichText(
                value: _ctrl.text,
                style: websiteHeaderStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final sideBySide = screenW >= 820;
    final dialogW = sideBySide ? 980.0 : (screenW < 560 ? screenW - 32 : 560.0);
    final contentH = sideBySide ? 420.0 : 520.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.title),
      content: SizedBox(
        width: dialogW,
        height: contentH + 56,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            const SizedBox(height: 12),
            Expanded(
              child:
                  sideBySide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildEditorPane()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPreviewPane()),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _buildEditorPane()),
                          const SizedBox(height: 12),
                          Expanded(flex: 2, child: _buildPreviewPane()),
                        ],
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
