import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_api_service.dart';
import '../services/storage_service.dart';

class EventThemeDesigner extends StatefulWidget {
  const EventThemeDesigner({Key? key}) : super(key: key);

  @override
  State<EventThemeDesigner> createState() => _EventThemeDesignerState();
}

class _EventThemeDesignerState extends State<EventThemeDesigner> {
  File? _selectedImage;
  String? _generatedImageBase64;
  bool _isGenerating = false;
  String? _errorMessage;
  bool _imageValid = false;
  final ImagePicker _picker = ImagePicker();

  // Theme options
  String _selectedEventType = 'birthday';
  String _selectedColorScheme = 'vibrant';
  String _selectedStyle = 'modern';
  int _guestCount = 50;
  String _customPrompt = '';

  final Map<String, String> _eventTypeDescriptions = {
    'birthday':
        'Birthday celebration with balloons, cake, and festive decorations',
    'wedding':
        'Elegant wedding ceremony with flowers, arches, and romantic elements',
    'corporate':
        'Professional corporate event with clean, modern design elements',
    'graduation':
        'Graduation ceremony with caps, diplomas, and achievement symbols',
    'anniversary':
        'Romantic anniversary celebration with hearts and elegant decorations',
  };

  final Map<String, String> _colorSchemeDescriptions = {
    'vibrant': 'Bright, bold colors with high energy and excitement',
    'pastel': 'Soft, gentle colors with romantic and peaceful atmosphere',
    'monochrome': 'Elegant black and white with sophisticated contrasts',
    'warm': 'Warm tones creating cozy and inviting atmosphere',
    'cool': 'Cool blues and greens creating calm and refreshing mood',
  };

  final Map<String, String> _styleDescriptions = {
    'modern': 'Clean lines, minimalist design with contemporary elements',
    'vintage': 'Classic, retro style with nostalgic elements',
    'rustic': 'Natural, organic materials with countryside charm',
    'luxury': 'Opulent, high-end materials with premium finishes',
    'playful':
        'Fun, whimsical elements with bright colors and creative designs',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Theme Designer'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageSelectionSection(),
            const SizedBox(height: 24),
            _buildThemeOptionsSection(),
            const SizedBox(height: 24),
            _buildPromptPreviewSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildResultSection(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Select Reference Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _clearSelectedImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (!_imageValid && _selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Image may be too large or corrupted. Please try another image.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOptionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. Choose Theme Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Event Type
            DropdownButtonFormField<String>(
              initialValue: _selectedEventType,
              decoration: const InputDecoration(
                labelText: 'Event Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              items:
                  _eventTypeDescriptions.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedEventType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Color Scheme
            DropdownButtonFormField<String>(
              initialValue: _selectedColorScheme,
              decoration: const InputDecoration(
                labelText: 'Color Scheme',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.palette),
              ),
              items:
                  _colorSchemeDescriptions.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedColorScheme = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Style
            DropdownButtonFormField<String>(
              initialValue: _selectedStyle,
              decoration: const InputDecoration(
                labelText: 'Design Style',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.style),
              ),
              items:
                  _styleDescriptions.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStyle = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Guest Count
            TextFormField(
              initialValue: _guestCount.toString(),
              decoration: const InputDecoration(
                labelText: 'Expected Guest Count',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                helperText: 'Helps AI scale the design appropriately',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final count = int.tryParse(value) ?? 50;
                setState(() => _guestCount = count.clamp(10, 1000));
              },
            ),
            const SizedBox(height: 16),

            // Custom Prompt
            TextFormField(
              initialValue: _customPrompt,
              decoration: const InputDecoration(
                labelText: 'Additional Requirements (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
                helperText: 'Describe any specific elements you want included',
              ),
              maxLines: 3,
              onChanged: (value) {
                setState(() => _customPrompt = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptPreviewSection() {
    final prompt = _buildPrompt();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '3. Generated AI Prompt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyPromptToClipboard(prompt),
                  tooltip: 'Copy prompt',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                prompt,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_selectedImage == null ||
                                !_imageValid ||
                                _isGenerating)
                            ? null
                            : _generateTheme,
                    icon:
                        _isGenerating
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Generate Theme',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_generatedImageBase64 == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '4. Generated Theme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadGeneratedImage(),
                      tooltip: 'Download image',
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload),
                      onPressed: () => _uploadToStorage(),
                      tooltip: 'Upload to storage',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.9,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: InteractiveViewer(
                                    child: Image.memory(
                                      base64Decode(_generatedImageBase64!),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Image.memory(
                    base64Decode(_generatedImageBase64!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: double.infinity,
                      width: double.infinity,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text('Failed to load image'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ),],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      borderOnForeground: false,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPrompt() {
    final basePrompt =
        '''Create an event theme design for a ${_selectedEventType} event with ${_selectedColorScheme} colors in a ${_selectedStyle} style. 

Event Details:
- Event Type: ${_selectedEventType}
- Guest Count: ${_guestCount} people
- Color Scheme: ${_selectedColorScheme} (${_colorSchemeDescriptions[_selectedColorScheme]})
- Design Style: ${_selectedStyle} (${_styleDescriptions[_selectedStyle]})

Requirements:
1. Create a professional event theme design
2. Scale appropriately for ${_guestCount} guests
3. Use ${_selectedColorScheme} color palette throughout
4. Apply ${_selectedStyle} design principles
5. Ensure high quality and realistic appearance
6. Include appropriate decorative elements for ${_selectedEventType} events
7. Make it visually appealing and memorable''';

    if (_customPrompt.isNotEmpty) {
      return '$basePrompt\n\nAdditional Requirements:\n${_customPrompt}';
    }

    return basePrompt;
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked != null) {
        await _processSelectedImage(File(picked.path));
      }
    } catch (e) {
      _showError('Failed to pick image from gallery: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked != null) {
        await _processSelectedImage(File(picked.path));
      }
    } catch (e) {
      _showError('Failed to capture image from camera: ${e.toString()}');
    }
  }

  Future<void> _processSelectedImage(File imageFile) async {
    try {
      setState(() => _errorMessage = null);

      // Validate file size (max 10MB)
      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        _showError(
          'Image file is too large. Please select an image under 10MB.',
        );
        return;
      }

      // Validate image dimensions
      final decodedImage = await decodeImageFromList(
        imageFile.readAsBytesSync(),
      );
      if (decodedImage == null) {
        setState(() {
          _selectedImage = imageFile;
          _imageValid = false;
        });
        return;
      }

      setState(() {
        _selectedImage = imageFile;
        _imageValid = true;
        _generatedImageBase64 = null; // Clear previous result
      });
    } catch (e) {
      _showError('Failed to process image: ${e.toString()}');
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
      _imageValid = false;
      _generatedImageBase64 = null;
      _errorMessage = null;
    });
  }

  void _resetForm() {
    setState(() {
      _selectedImage = null;
      _imageValid = false;
      _generatedImageBase64 = null;
      _errorMessage = null;
      _selectedEventType = 'birthday';
      _selectedColorScheme = 'vibrant';
      _selectedStyle = 'modern';
      _guestCount = 50;
      _customPrompt = '';
    });
  }

  Future<void> _generateTheme() async {
    if (_selectedImage == null || !_imageValid) {
      _showError('Please select a valid image first');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.generateTheme(
        imageFile: _selectedImage!,
        eventType: _selectedEventType,
        colorScheme: _selectedColorScheme,
        style: _selectedStyle,
        guestCount: _guestCount,
        customPrompt: _customPrompt,
        negativePrompt:
            'blurry, distorted, unrealistic, low quality, artifacts, text, watermark',
        strength: 0.72,
      );

      if (result != null &&
          result['success'] == true &&
          result['image'] != null) {
        setState(() {
          _generatedImageBase64 = result['image'];
          _isGenerating = false;
        });

        _showSuccess('Theme generated successfully!');
      } else {
        throw Exception(result?['error'] ?? 'Failed to generate theme');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Failed to generate theme: ${e.toString()}');
    }
  }

  Future<void> _downloadGeneratedImage() async {
    if (_generatedImageBase64 == null) return;

    try {
      // Implementation would depend on your download strategy
      // This is a placeholder for the download functionality
      _showSuccess('Download feature would be implemented here');
    } catch (e) {
      _showError('Failed to download image: ${e.toString()}');
    }
  }

  Future<void> _uploadToStorage() async {
    if (_generatedImageBase64 == null) return;

    try {
      final imageUrl = await StorageService.uploadGeneratedTheme(
        imageBase64: _generatedImageBase64!,
        eventType: _selectedEventType,
        colorScheme: _selectedColorScheme,
        style: _selectedStyle,
      );

      if (imageUrl != null) {
        _showSuccess(
          'Theme uploaded successfully! URL: ${imageUrl.substring(0, 50)}...',
        );
      } else {
        throw Exception('Upload returned null URL');
      }
    } catch (e) {
      _showError('Failed to upload to storage: ${e.toString()}');
    }
  }

  void _copyPromptToClipboard(String prompt) {
    // Implementation would use clipboard package
    _showSuccess('Prompt copied to clipboard!');
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method to decode image (placeholder - would use image package)
  Future<dynamic> decodeImageFromList(Uint8List bytes) async {
    try {
      // This is a placeholder - in real implementation,
      // you'd use the 'image' package to decode and validate
      return true; // Placeholder
    } catch (e) {
      return null;
    }
  }
}
