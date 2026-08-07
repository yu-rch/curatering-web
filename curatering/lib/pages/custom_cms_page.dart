import 'package:flutter/material.dart';

import '../services/website_content_store.dart';
import '../widgets/cms_sections.dart';
import '../widgets/customer_site_footer.dart';
import '../widgets/customer_website_topbar.dart';
import '../utils/responsive_layout.dart';

/// Public CMS custom page at `/p/:slug`.
class CustomCmsPage extends StatefulWidget {
  const CustomCmsPage({super.key, required this.slug});

  final String slug;

  @override
  State<CustomCmsPage> createState() => _CustomCmsPageState();
}

class _CustomCmsPageState extends State<CustomCmsPage> {
  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = WebsiteContentStore.instance;
    CmsCustomPage? page;
    for (final p in store.customPages) {
      if (p.slug == widget.slug) {
        page = p;
        break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const CustomerWebsiteTopBar(),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                if (page == null) {
                  return const Center(child: Text('Page not found'));
                }
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobileWidth(context) ? 16 : 40,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            page.title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CmsSectionsView(sections: page.sections),
                          const SizedBox(height: 48),
                          CustomerSiteFooter(store: store),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
