part of 'customer_website.dart';

extension _ThemeEditorPageExtraction on _InquireFormState {
  static const Duration _aiRequestTimeout = Duration(seconds: 180);
  void _showDesignMyEventEditorPage() {
    final baseCarouselCtrl = PageController(
      viewportFraction: 0.86,
      initialPage: _designEventBaseCarouselPage.clamp(
        0,
        (_themeSuggestions.length - 1).clamp(0, 9999),
      ),
    );
    final addonCarouselCtrl = PageController(
      viewportFraction: 0.86,
      initialPage: _designEventAddonCarouselPage.clamp(
        0,
        (_themeSuggestions.length - 1).clamp(0, 9999),
      ),
    );
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder:
                (dialogContext) => StatefulBuilder(
                  builder: (context, setDialogState) {
                    void refreshDialog() {
                      if (mounted) setDialogState(() {});
                    }

                    final leftColumn = _buildThemeEditorLeftPane(
                      dialogContext: dialogContext,
                      refreshDialog: refreshDialog,
                      addLinkedBaseImage:
                          () => _themeEditorAddLinkedBaseImage(
                            context,
                            refreshDialog,
                          ),
                    );

                    final rightActions = _buildThemeEditorRightPane(
                      dialogContext: dialogContext,
                      refreshDialog: refreshDialog,
                      setDialogState: setDialogState,
                      lockBaseAndAdvance:
                          () => _themeEditorLockBaseAndAdvance(refreshDialog),
                      advanceToCompose:
                          () => _themeEditorAdvanceToCompose(refreshDialog),
                    );

                    return Scaffold(
                      backgroundColor: const Color(0xFFF7F8FA),
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        titleSpacing: 0,
                        leading: IconButton(
                          tooltip: 'Back to Online Inquiry',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        title: const Text(
                          'Event Theme Design Studio',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      body: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 340, child: leftColumn),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _buildThemeEditorPreviewPane(
                                refreshDialog,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            SizedBox(width: 320, child: rightActions),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        )
        .whenComplete(() {
          _linkedBaseUrlCtrl.clear();
          _addByPromptCtrl.clear();
          baseCarouselCtrl.dispose();
          addonCarouselCtrl.dispose();
        });
  }

  void _themeEditorAddLinkedBaseImage(
    BuildContext context,
    VoidCallback refreshDialog,
  ) {
    final input = _linkedBaseUrlCtrl.text.trim();
    final uri = Uri.tryParse(input);
    if (input.isEmpty ||
        uri == null ||
        !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid image URL (http/https).'),
        ),
      );
      return;
    }
    setState(() {
      _themeSuggestions.insert(0, {
        'imageUrl': input,
        'thumbnailUrl': input,
        'title': 'Linked base image',
        'source': 'manual_link',
      });
      _designEventBaseCarouselPage = 0;
      _pendingBaseSuggestionIndex = 0;
    });
    _linkedBaseUrlCtrl.clear();
    refreshDialog();
  }

  Future<void> _themeEditorLockBaseAndAdvance(
    VoidCallback refreshDialog,
  ) async {
    final idx = _pendingBaseSuggestionIndex;
    if (idx == null || idx < 0 || idx >= _themeSuggestions.length) return;
    final url = (_themeSuggestions[idx]['imageUrl'] ?? '').toString();
    if (url.isEmpty) return;
    setState(() {
      _isLockingBase = true;
      _selectedBaseImage = url;
      _designEventWizardStep = 1;
      _selectedSuggestionIndexes.clear();
      // Clear theme search to allow separate source image searching
      _themeSuggestions.clear();
      _themeSearchPage = 1;
      _themeSearchHasMore = false;
      _themeSearchTotal = 0;
      _isSearchingThemeImages = false;
    });
    try {
      await _cacheBaseImageNaturalSize();
      await _analyzeBaseAndRecommend();
    } finally {
      if (mounted) setState(() => _isLockingBase = false);
    }
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorAdvanceToCompose(VoidCallback refreshDialog) async {
    if (_selectedSuggestionIndexes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select at least one add-on image to continue.'),
          ),
        );
      }
      return;
    }
    if (_isExtractingThemeObjects || _isSearchingThemeImages) return;
    setState(() => _isExtractingThemeObjects = true);
    refreshDialog();
    try {
      await _extractSelectedObjects();
      if (_baseFreeSpaces.isNotEmpty && _extractedThemeObjects.isNotEmpty) {
        await _autoPlaceSelectedObjects();
      }
    } finally {
      if (mounted) refreshDialog();
    }
    setState(() => _designEventWizardStep = 2);
    refreshDialog();
  }

  Widget _buildThemeEditorPreviewPane(VoidCallback refreshDialog) {
    if (_designEventWizardStep == 2 && _selectedBaseImage != null) {
      return LayoutBuilder(
        builder:
            (ctx, bc) => Stack(
              children: [
                _buildPlacementEditor(
                  baseImage: _selectedBaseImage!,
                  placedObjects: _placedThemeObjects,
                  extractedObjects: _extractedThemeObjects,
                  onChanged: refreshDialog,
                  editorWidth: bc.maxWidth,
                  editorMaxHeight: bc.maxHeight,
                ),
                if (_isExtractingThemeObjects)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Extracting objects...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isAutoPlacing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Auto placing objects...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isRenderingComposite)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Rendering composite...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isAnalyzingBase)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Analyzing base image...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isAddingByPrompt)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Adding objects by prompt...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      );
    }
    final img =
        _designEventWizardStep == 0
            ? ((_pendingBaseSuggestionIndex != null &&
                    _pendingBaseSuggestionIndex! >= 0 &&
                    _pendingBaseSuggestionIndex! < _themeSuggestions.length)
                ? (_themeSuggestions[_pendingBaseSuggestionIndex!]['imageUrl'] ??
                        '')
                    .toString()
                : (_themeSuggestions.isNotEmpty
                    ? (_themeSuggestions[_designEventBaseCarouselPage.clamp(
                              0,
                              _themeSuggestions.length - 1,
                            )]['imageUrl'] ??
                            '')
                        .toString()
                    : ''))
            : (_selectedBaseImage ?? '');
    if (img.trim().isEmpty) {
      return Center(
        child: Text(
          'Select a base image.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 3,
          child: Center(child: _designImagePreview(img, fit: BoxFit.contain)),
        ),
        if (_isSearchingThemeImages)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching images...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThemeEditorImageCard({
    required BuildContext dialogContext,
    required int idx,
    required bool isBaseStep,
    required VoidCallback refreshDialog,
  }) {
    final imageUrl = (_themeSuggestions[idx]['imageUrl'] ?? '').toString();
    final photographer =
        (_themeSuggestions[idx]['photographer'] ?? '').toString();
    final pexelsUrl = (_themeSuggestions[idx]['pexelsUrl'] ?? '').toString();
    final selected = _selectedSuggestionIndexes.contains(idx);
    final isMarkedBase = _pendingBaseSuggestionIndex == idx;
    final isBase = !isBaseStep && (_selectedBaseImage ?? '') == imageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AspectRatio(
        aspectRatio: 1.8,
        child: GestureDetector(
          onTap: () => _showThemeImageEnlargeDialog(dialogContext, imageUrl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _designImagePreview(imageUrl, fit: BoxFit.cover),
              ),
              if (isBase)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black26,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Base image',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (pexelsUrl.isNotEmpty)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openExternalLink(pexelsUrl),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.open_in_new, size: 16),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        if (isBaseStep) {
                          _pendingBaseSuggestionIndex =
                              isMarkedBase ? null : idx;
                        } else if (!isBase) {
                          if (selected) {
                            _selectedSuggestionIndexes.remove(idx);
                          } else {
                            _selectedSuggestionIndexes.add(idx);
                          }
                        }
                      });
                      refreshDialog();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isBaseStep
                            ? (isMarkedBase
                                ? Icons.check_box
                                : Icons.check_box_outline_blank)
                            : (selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank),
                        color:
                            isBaseStep
                                ? (isMarkedBase
                                    ? const Color(0xFF1976D2)
                                    : Colors.grey.shade700)
                                : (selected
                                    ? const Color(0xFF1DB954)
                                    : Colors.grey.shade700),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              if (photographer.isNotEmpty)
                Positioned(
                  left: 6,
                  right: 50,
                  bottom: 6,
                  child: PexelsAttributionBadge(photographer: photographer),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeEditorLeftPane({
    required BuildContext dialogContext,
    required VoidCallback refreshDialog,
    required VoidCallback addLinkedBaseImage,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Info Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Event: ${_eventTitle.text.trim().isEmpty ? "(not set)" : _eventTitle.text.trim()}',
                ),
                Text('Type: $_eventType'),
                Text('Formality: $_formality'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 1: Template Selection (Base Image)
          if (_designEventWizardStep == 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Step 1: Choose Template',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for a base template or paste a URL',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _themeRequestCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Template search',
                      hintText: 'e.g. wedding flowers, birthday party',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed:
                        _isSearchingThemeImages
                            ? null
                            : () async =>
                                _themeEditorSearchThemeImages(refreshDialog),
                    icon:
                        _isSearchingThemeImages
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.search, size: 18),
                    label: Text(
                      _isSearchingThemeImages
                          ? 'Searching...'
                          : 'Search Templates',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _linkedBaseUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Or paste template URL',
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: addLinkedBaseImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Add URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Step 2: Element Selection
          if (_designEventWizardStep == 1) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.widgets, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Step 2: Add Elements',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for decorative elements to enhance your template',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _themeRequestCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Element search',
                      hintText: 'e.g. flowers, candles, decorations',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed:
                        _isSearchingThemeImages
                            ? null
                            : () async =>
                                _themeEditorSearchThemeImages(refreshDialog),
                    icon:
                        _isSearchingThemeImages
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.search, size: 18),
                    label: Text(
                      _isSearchingThemeImages
                          ? 'Searching...'
                          : 'Search Elements',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Search Results Section
          if (_themeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _designEventWizardStep == 0 ? 'Templates' : 'Elements',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _themeSearchTotal > 0
                        ? 'Page $_themeSearchPage of ${_themeSearchMaxPages()} · ${_themeSuggestions.length} on this page · $_themeSearchTotal total'
                        : 'Page $_themeSearchPage · ${_themeSuggestions.length} item(s) shown',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            (_isSearchingThemeImages || _themeSearchPage <= 1)
                                ? null
                                : () async {
                                  await _searchThemeSuggestions(
                                    goToPage: _themeSearchPage - 1,
                                  );
                                  if (mounted) refreshDialog();
                                },
                        icon: const Icon(Icons.chevron_left, size: 20),
                        label: const Text('Previous'),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed:
                            (_isSearchingThemeImages || !_themeSearchHasMore)
                                ? null
                                : () async {
                                  await _searchThemeSuggestions(
                                    goToPage: _themeSearchPage + 1,
                                  );
                                  if (mounted) refreshDialog();
                                },
                        icon: const Icon(Icons.chevron_right, size: 20),
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        (_isSearchingThemeImages || !_themeSearchHasMore)
                            ? null
                            : () async {
                              await _searchThemeSuggestions(loadMore: true);
                              if (mounted) refreshDialog();
                            },
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(
                      _themeSearchHasMore ? 'Load more' : 'No more to load',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Image Grid
          if (_themeSuggestions.isNotEmpty)
            ...List.generate(
              _themeSuggestions.length,
              (idx) => _buildThemeEditorImageCard(
                dialogContext: dialogContext,
                idx: idx,
                isBaseStep: _designEventWizardStep == 0,
                refreshDialog: refreshDialog,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    _designEventWizardStep == 0
                        ? Icons.image_outlined
                        : Icons.widgets_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _designEventWizardStep == 0
                        ? 'Search for templates to get started'
                        : 'Search for elements to enhance your design',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThemeEditorRightPane({
    required BuildContext dialogContext,
    required VoidCallback refreshDialog,
    required void Function(void Function()) setDialogState,
    required Future<void> Function() lockBaseAndAdvance,
    required Future<void> Function() advanceToCompose,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _designEventWizardStep == 0
                  ? 'Mark one base image, then proceed.'
                  : _designEventWizardStep == 1
                  ? 'Check one or more images (not the base) to use as extraction sources.'
                  : 'Compose your design on canvas.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            if (_designEventWizardStep == 2) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addByPromptCtrl,
                      onChanged: (_) => refreshDialog(),
                      onSubmitted: (_) {
                        if (_selectedBaseImage != null &&
                            _addByPromptCtrl.text.trim().isNotEmpty &&
                            !_isAddingByPrompt) {
                          _themeEditorAddByPrompt(refreshDialog);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Add by prompt',
                        hintText: 'e.g. add more flowers on table',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        (_selectedBaseImage != null &&
                                _addByPromptCtrl.text.trim().isNotEmpty &&
                                !_isAddingByPrompt)
                            ? () async => _themeEditorAddByPrompt(refreshDialog)
                            : null,
                    icon:
                        _isAddingByPrompt
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.send, size: 18),
                    label: Text(_isAddingByPrompt ? 'Adding' : ''),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed:
                        _isExtractingThemeObjects
                            ? null
                            : () async => _themeEditorExtractObjects(
                              refreshDialog,
                              setDialogState: setDialogState,
                            ),
                    child: Text(
                      _isExtractingThemeObjects ? 'Segmenting...' : 'Extract',
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        _placedThemeObjects.isNotEmpty ||
                                _extractedThemeObjects.isNotEmpty
                            ? () async => _themeEditorAutoPlace(refreshDialog)
                            : null,
                    child: const Text('Auto Place'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_placedThemeObjects.isNotEmpty && !_isPlacementSaved)
                            ? () async =>
                                _themeEditorSavePlacement(refreshDialog)
                            : null,
                    child: Text(
                      _isPlacementSaved ? 'Placement Saved' : 'Save Placement',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isPlacementSaved ? Colors.grey : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_selectedBaseImage != null &&
                                _placedThemeObjects.isNotEmpty &&
                                _isPlacementSaved &&
                                !_isRenderingComposite)
                            ? () async =>
                                _themeEditorRenderComposite(refreshDialog)
                            : null,
                    child: Text(
                      _isRenderingComposite ? 'Rendering...' : 'Render',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (_designEventWizardStep > 0)
                  TextButton.icon(
                    onPressed: () => _themeEditorStepBack(refreshDialog),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                  ),
                const Spacer(),
                if (_designEventWizardStep == 0)
                  ElevatedButton(
                    onPressed:
                        (_pendingBaseSuggestionIndex != null &&
                                !_isSearchingThemeImages &&
                                !_isLockingBase)
                            ? () async => lockBaseAndAdvance()
                            : null,
                    child:
                        _isLockingBase
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Next'),
                  )
                else if (_designEventWizardStep == 1)
                  ElevatedButton(
                    onPressed:
                        _selectedSuggestionIndexes.isEmpty ||
                                _isExtractingThemeObjects
                            ? null
                            : () async => advanceToCompose(),
                    child:
                        _isExtractingThemeObjects
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Next: Compose'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if ((_confirmedCompositeBase64 ?? '').isNotEmpty)
              ElevatedButton(
                onPressed: () => _themeEditorApplyAndReturn(dialogContext),
                child: const Text('Apply and Return'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _themeEditorClose(dialogContext),
              child: const Text('Back to Online Inquiry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _themeEditorSearchThemeImages(VoidCallback refreshDialog) async {
    await _searchThemeSuggestions();
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorExtractObjects(
    VoidCallback refreshDialog, {
    void Function(void Function())? setDialogState,
  }) async {
    await _extractSelectedObjects();
    if (mounted) {
      refreshDialog();
      // Automatically trigger recolor dialog after extraction
      if (_extractedThemeObjects.isNotEmpty && setDialogState != null) {
        await _runRecolorWithExtractedObjects(setDialogState);
        if (mounted) refreshDialog();
      }
    }
  }

  Future<void> _themeEditorAutoPlace(VoidCallback refreshDialog) async {
    await _autoPlaceSelectedObjects();
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorAddByPrompt(VoidCallback refreshDialog) async {
    await _addObjectsByPromptAndRender();
    if (mounted) refreshDialog();
  }

  Future<void> _runRecolorWithExtractedObjects(
    void Function(void Function()) setDialogState,
  ) async {
    final selection = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String? selectedObjectId;
        String selectedHex = '#F4511E';
        double selectedAlpha = 1.0;
        const palette = <String>[
          '#F4511E',
          '#1DB954',
          '#1976D2',
          '#E91E63',
          '#6A1B9A',
          '#FFC107',
          '#FFFFFF',
          '#212121',
        ];
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: const Color(0xFFF7F8FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Container(
                width: 800,
                height: 600,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recolor Extracted Objects',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF4511E),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Extracted Objects:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              _extractedThemeObjects.map((obj) {
                                                final id =
                                                    (obj['id'] ?? '')
                                                        .toString();
                                                final label =
                                                    (obj['label'] ?? 'Object')
                                                        .toString();
                                                final active =
                                                    selectedObjectId == id;
                                                return FilterChip(
                                                  label: Text(
                                                    '$label #${id.split('_').last}',
                                                  ),
                                                  selected: active,
                                                  onSelected:
                                                      (_) => setLocalState(() {
                                                        selectedObjectId = id;
                                                      }),
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  selectedColor: Colors.purple
                                                      .withOpacity(0.3),
                                                  checkmarkColor: Colors.purple,
                                                );
                                              }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Color Selection:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          palette.map((hex) {
                                            final selected = selectedHex == hex;
                                            return GestureDetector(
                                              onTap:
                                                  () => setLocalState(
                                                    () => selectedHex = hex,
                                                  ),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                    int.parse(
                                                          hex.substring(1),
                                                          radix: 16,
                                                        ) +
                                                        0xFF000000,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        selected
                                                            ? Colors.black
                                                            : Colors.black26,
                                                    width: selected ? 3 : 1,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Alpha: ${(selectedAlpha * 100).round()}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Slider(
                                          value: selectedAlpha,
                                          min: 0.0,
                                          max: 1.0,
                                          divisions: 20,
                                          activeColor: Color(
                                            int.parse(
                                                  selectedHex.substring(1),
                                                  radix: 16,
                                                ) +
                                                0xFF000000,
                                          ),
                                          onChanged:
                                              (value) => setLocalState(
                                                () => selectedAlpha = value,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          int.parse(
                                                selectedHex.substring(1),
                                                radix: 16,
                                              ) +
                                              (selectedAlpha * 255).round() *
                                                  0x1000000,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Preview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          selectedObjectId == null
                              ? null
                              : () => Navigator.of(context).pop({
                                'objectId': selectedObjectId!,
                                'hex': selectedHex,
                                'alpha': selectedAlpha,
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply Color'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selection == null) return;
    final objectId = selection['objectId'];
    final targetHex = selection['hex'];
    final targetAlpha = selection['alpha'] as double? ?? 1.0;

    final targetObject = _extractedThemeObjects.firstWhere(
      (obj) => (obj['id'] ?? '').toString() == objectId,
      orElse: () => <String, dynamic>{},
    );

    if (targetObject.isEmpty) return;

    final objectImageBase64 =
        (targetObject['objectImageBase64'] ?? '').toString();
    if (objectImageBase64.isEmpty) return;

    setState(() => _isDetectingAiObjects = true);
    try {
      final recolor = await PublicEventsApi.instance
          .swapThemeObjectColors(
            imageBase64: objectImageBase64,
            masks: [
              {'objectId': objectId},
            ],
            edits: [
              {
                'objectId': objectId,
                'targetHex': targetHex,
                'intensity': targetAlpha,
              },
            ],
          )
          .timeout(_aiRequestTimeout);

      final recoloredBase64 = (recolor['imageBase64'] ?? '').toString();
      if (recoloredBase64.isNotEmpty) {
        setState(() {
          final index = _extractedThemeObjects.indexWhere(
            (obj) => (obj['id'] ?? '').toString() == objectId,
          );
          if (index >= 0) {
            _extractedThemeObjects[index] = {
              ..._extractedThemeObjects[index],
              'objectImageBase64': recoloredBase64,
            };
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Object recolored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recolor failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDetectingAiObjects = false);
    }
  }

  Future<void> _themeEditorRenderComposite(VoidCallback refreshDialog) async {
    await _renderComposite();
    if (mounted) refreshDialog();
  }

  void _themeEditorStepBack(VoidCallback refreshDialog) {
    setState(() {
      if (_designEventWizardStep == 2) {
        _designEventWizardStep = 1;
      } else if (_designEventWizardStep == 1) {
        _designEventWizardStep = 0;
      }
    });
    refreshDialog();
  }

  void _themeEditorApplyAndReturn(BuildContext dialogContext) {
    final edited = _confirmedCompositeBase64?.trim() ?? '';
    if (edited.isEmpty) return;
    setState(() {
      _wantsCustomDesign = false;
      _designPhotoUrls
        ..clear()
        ..add(edited);
      _focusedPhotoIndex = 0;
    });
    Navigator.pop(dialogContext);
  }

  Future<void> _themeEditorSavePlacement(VoidCallback refreshDialog) async {
    if (_placedThemeObjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No objects placed to save.')),
        );
      }
      return;
    }

    setState(() {
      _isPlacementSaved = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Placement saved! You can now render the final design.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    if (mounted) refreshDialog();
  }

  void _themeEditorClose(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
  }
}
