// ignore_for_file: invalid_use_of_protected_member

part of 'customer_website.dart';

extension _ThemeEditorPageExtraction on _InquireFormState {
  void _showDesignMyEventEditorPage() {
    final baseCarouselCtrl = PageController(
      viewportFraction: 0.86,
      initialPage: _designEventBaseCarouselPage.clamp(0, (_themeSuggestions.length - 1).clamp(0, 9999)),
    );
    final addonCarouselCtrl = PageController(
      viewportFraction: 0.86,
      initialPage: _designEventAddonCarouselPage.clamp(0, (_themeSuggestions.length - 1).clamp(0, 9999)),
    );
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            void refreshDialog() {
              if (mounted) setDialogState(() {});
            }

            final leftColumn = _buildThemeEditorLeftPane(
              dialogContext: dialogContext,
              refreshDialog: refreshDialog,
              addLinkedBaseImage: () => _themeEditorAddLinkedBaseImage(context, refreshDialog),
            );

            final rightActions = _buildThemeEditorRightPane(
              dialogContext: dialogContext,
              refreshDialog: refreshDialog,
              setDialogState: setDialogState,
              lockBaseAndAdvance: () => _themeEditorLockBaseAndAdvance(refreshDialog),
              advanceToCompose: () => _themeEditorAdvanceToCompose(refreshDialog),
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
                title: const Text('Event Theme Design Studio', style: TextStyle(color: Colors.black87)),
              ),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 340, child: leftColumn),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildThemeEditorPreviewPane(refreshDialog)),
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

  void _themeEditorAddLinkedBaseImage(BuildContext context, VoidCallback refreshDialog) {
    final input = _linkedBaseUrlCtrl.text.trim();
    final uri = Uri.tryParse(input);
    if (input.isEmpty || uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid image URL (http/https).')),
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

  Future<void> _themeEditorLockBaseAndAdvance(VoidCallback refreshDialog) async {
    final idx = _pendingBaseSuggestionIndex;
    if (idx == null || idx < 0 || idx >= _themeSuggestions.length) return;
    final url = (_themeSuggestions[idx]['imageUrl'] ?? '').toString();
    if (url.isEmpty) return;
    setState(() {
      _selectedBaseImage = url;
      _designEventWizardStep = 1;
      _selectedSuggestionIndexes.clear();
    });
    await _cacheBaseImageNaturalSize();
    await _analyzeBaseAndRecommend();
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorAdvanceToCompose(VoidCallback refreshDialog) async {
    if (_selectedSuggestionIndexes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one add-on image to continue.')),
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
        builder: (ctx, bc) => _buildPlacementEditor(
          baseImage: _selectedBaseImage!,
          placedObjects: _placedThemeObjects,
          extractedObjects: _extractedThemeObjects,
          onChanged: refreshDialog,
          editorWidth: bc.maxWidth,
          editorMaxHeight: bc.maxHeight,
        ),
      );
    }
    final img = _designEventWizardStep == 0
        ? ((_pendingBaseSuggestionIndex != null &&
                    _pendingBaseSuggestionIndex! >= 0 &&
                    _pendingBaseSuggestionIndex! < _themeSuggestions.length)
                ? (_themeSuggestions[_pendingBaseSuggestionIndex!]['imageUrl'] ?? '').toString()
                : (_themeSuggestions.isNotEmpty
                    ? (_themeSuggestions[_designEventBaseCarouselPage.clamp(0, _themeSuggestions.length - 1)]['imageUrl'] ?? '')
                        .toString()
                    : ''))
        : (_selectedBaseImage ?? '');
    if (img.trim().isEmpty) {
      return Center(child: Text('Select a base image.', style: TextStyle(color: Colors.grey.shade600)));
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3,
      child: Center(child: _designImagePreview(img, fit: BoxFit.contain)),
    );
  }

  Widget _buildThemeEditorImageCard({
    required BuildContext dialogContext,
    required int idx,
    required bool isBaseStep,
    required VoidCallback refreshDialog,
  }) {
    final imageUrl = (_themeSuggestions[idx]['imageUrl'] ?? '').toString();
    final photographer = (_themeSuggestions[idx]['photographer'] ?? '').toString();
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
                  child: const Text('Base image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                          _pendingBaseSuggestionIndex = isMarkedBase ? null : idx;
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
                            ? (isMarkedBase ? Icons.check_box : Icons.check_box_outline_blank)
                            : (selected ? Icons.check_box : Icons.check_box_outline_blank),
                        color: isBaseStep
                            ? (isMarkedBase ? const Color(0xFF1976D2) : Colors.grey.shade700)
                            : (selected ? const Color(0xFF1DB954) : Colors.grey.shade700),
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
          Text('Event: ${_eventTitle.text.trim().isEmpty ? "(not set)" : _eventTitle.text.trim()}'),
          Text('Type: $_eventType'),
          Text('Formality: $_formality'),
          const SizedBox(height: 12),
          TextField(
            controller: _themeRequestCtrl,
            decoration: const InputDecoration(
              labelText: 'Theme prompt',
              hintText: 'e.g. debut purple sea theme',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if ((_selectedBaseImage ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Base context linked for search: ${_selectedBaseImage!.length > 90 ? "${_selectedBaseImage!.substring(0, 90)}..." : _selectedBaseImage!}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isSearchingThemeImages
                ? null
                : () async => _themeEditorSearchThemeImages(refreshDialog),
            icon: _isSearchingThemeImages
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, size: 18),
            label: Text(_isSearchingThemeImages ? 'Searching...' : 'Search Theme Images'),
          ),
          if (_themeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _themeSearchTotal > 0
                  ? 'Page $_themeSearchPage of ${_themeSearchMaxPages()} · ${_themeSuggestions.length} on this page · $_themeSearchTotal total'
                  : 'Page $_themeSearchPage · ${_themeSuggestions.length} image(s) shown',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: (_isSearchingThemeImages || _themeSearchPage <= 1)
                      ? null
                      : () async {
                          await _searchThemeSuggestions(goToPage: _themeSearchPage - 1);
                          if (mounted) refreshDialog();
                        },
                  icon: const Icon(Icons.chevron_left, size: 20),
                  label: const Text('Previous'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: (_isSearchingThemeImages || !_themeSearchHasMore)
                      ? null
                      : () async {
                          await _searchThemeSuggestions(goToPage: _themeSearchPage + 1);
                          if (mounted) refreshDialog();
                        },
                  icon: const Icon(Icons.chevron_right, size: 20),
                  label: const Text('Next'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: (_isSearchingThemeImages || !_themeSearchHasMore)
                  ? null
                  : () async {
                      await _searchThemeSuggestions(loadMore: true);
                      if (mounted) refreshDialog();
                    },
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(_themeSearchHasMore ? 'Load more (append next page)' : 'No more to load'),
            ),
          ],
          const SizedBox(height: 12),
          if (_designEventWizardStep == 0) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkedBaseUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paste base image URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: addLinkedBaseImage, child: const Text('Add URL')),
              ],
            ),
            const SizedBox(height: 10),
          ],
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
            Text('Run a search to load inspiration photos.', style: TextStyle(color: Colors.grey.shade600)),
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
              TextField(
                controller: _addByPromptCtrl,
                onChanged: (_) => refreshDialog(),
                decoration: const InputDecoration(
                  labelText: 'Add by prompt',
                  hintText: 'e.g. add more flowers on table',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isExtractingThemeObjects
                        ? null
                        : () async => _themeEditorExtractObjects(refreshDialog),
                    child: Text(_isExtractingThemeObjects ? 'Segmenting...' : 'Extract'),
                  ),
                  ElevatedButton(
                    onPressed: _isDetectingAiObjects
                        ? null
                        : () async => _themeEditorRecolor(setDialogState, refreshDialog),
                    child: Text(_isDetectingAiObjects ? 'Detecting...' : 'Recolor'),
                  ),
                  ElevatedButton(
                    onPressed: _placedThemeObjects.isNotEmpty || _extractedThemeObjects.isNotEmpty
                        ? () async => _themeEditorAutoPlace(refreshDialog)
                        : null,
                    child: const Text('Auto Place'),
                  ),
                  ElevatedButton(
                    onPressed: (_selectedBaseImage != null && _addByPromptCtrl.text.trim().isNotEmpty && !_isAddingByPrompt)
                        ? () async => _themeEditorAddByPrompt(refreshDialog)
                        : null,
                    child: Text(_isAddingByPrompt ? 'Adding...' : 'Add By Prompt'),
                  ),
                  ElevatedButton(
                    onPressed: (_selectedBaseImage != null &&
                            _placedThemeObjects.isNotEmpty &&
                            _isPlacementSaved &&
                            !_isRenderingComposite)
                        ? () async => _themeEditorRenderComposite(refreshDialog)
                        : null,
                    child: Text(_isRenderingComposite ? 'Rendering...' : 'Render'),
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
                    onPressed: (_pendingBaseSuggestionIndex != null && !_isSearchingThemeImages)
                        ? () async => lockBaseAndAdvance()
                        : null,
                    child: const Text('Next'),
                  )
                else if (_designEventWizardStep == 1)
                  ElevatedButton(
                    onPressed: _selectedSuggestionIndexes.isEmpty ? null : () async => advanceToCompose(),
                    child: const Text('Next: Compose'),
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

  Future<void> _themeEditorExtractObjects(VoidCallback refreshDialog) async {
    await _extractSelectedObjects();
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorRecolor(void Function(void Function()) setDialogState, VoidCallback refreshDialog) async {
    await _runCustomerEditObjectsFlow(setDialogState);
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorAutoPlace(VoidCallback refreshDialog) async {
    await _autoPlaceSelectedObjects();
    if (mounted) refreshDialog();
  }

  Future<void> _themeEditorAddByPrompt(VoidCallback refreshDialog) async {
    await _addObjectsByPromptAndRender();
    if (mounted) refreshDialog();
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

  void _themeEditorClose(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
  }
}
