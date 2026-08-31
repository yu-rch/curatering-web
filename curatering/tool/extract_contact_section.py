from pathlib import Path

src = Path(__file__).resolve().parent.parent / "lib" / "pages" / "customer_website.dart"
lines = src.read_text(encoding="utf-8").splitlines()
start = next(i for i, line in enumerate(lines) if line.startswith("class _ContactSection"))
body = lines[start:]
header = """import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/website_content_store.dart';
import '../widgets/antd_message.dart';
import '../widgets/contact_address_map.dart';
import '../widgets/website_rich_text.dart';
import '../theme/website_header_font.dart';
import '../utils/responsive_layout.dart';

"""
text = header + "\n".join(body)
text = text.replace("class _ContactSection", "class CustomerContactSection", 1)
text = text.replace("_ContactSectionState", "_CustomerContactSectionState")
text = text.replace("State<_ContactSection>", "State<CustomerContactSection>")
text = text.replace("_ContactSection({", "CustomerContactSection({")
text = text.replace("websitePagePadding(", "appPagePadding(")
text = text.replace("websiteContentMaxWidth(", "appContentMaxWidth(")

out = Path(__file__).resolve().parent.parent / "lib" / "pages" / "customer_contact_section.dart"
out.write_text(text + "\n", encoding="utf-8")
src.write_text("\n".join(lines[:start]) + "\n", encoding="utf-8")
print(f"Wrote {out.name} ({len(body)} lines), trimmed {src.name} to {start} lines")
