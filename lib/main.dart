
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const LunaPro());
}

class LunaPro extends StatelessWidget {
  const LunaPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luna Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB89AFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Uint8List? original;
  Uint8List? preview;

  double brightness = 1.0;
  double contrast = 1.0;
  double saturation = 1.0;
  bool busy = false;

  Future<void> pickPhoto() async {
    if (busy) return;

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        original = bytes;
        preview = bytes;
        brightness = 1.0;
        contrast = 1.0;
        saturation = 1.0;
      });
    } catch (e) {
      showError('Could not open photo');
    }
  }

  Uint8List process(
    Uint8List bytes, {
    bool small = false,
  }) {
    var image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unsupported image');
    }

    image = img.bakeOrientation(image);

    if (small && image.width > 1000) {
      image = img.copyResize(
        image,
        width: 1000,
      );
    }

    final edited = img.adjustColor(
      image,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );

    return Uint8List.fromList(
      img.encodeJpg(
        edited,
        quality: small ? 85 : 95,
      ),
    );
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> updatePreview() async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final result = process(
        original!,
        small: true,
      );

      if (!mounted) return;

      setState(() {
        preview = result;
      });
    } catch (e) {
      showError('Editing failed');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> exportPhoto() async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final result = process(original!);

      final file = XFile.fromData(
        result,
        mimeType: 'image/jpeg',
        name: 'luna_edit.jpg',
      );

      await Share.shareXFiles(
        [file],
        fileNameOverrides: ['luna_edit.jpg'],
      );
    } catch (e) {
      showError('Could not export photo');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void reset() {
    if (original == null) return;

    setState(() {
      brightness = 1.0;
      contrast = 1.0;
      saturation = 1.0;
      preview = original;
    });
  }

  Widget buildSlider(
    String title,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(value.toStringAsFixed(2)),
            ],
          ),
        ),
        Slider(
          value: value,
          min: 0,
          max: 2,
          onChanged: busy
              ? null
              : (value) {
                  setState(() {
                    onChanged(value);
                  });
                },
          onChangeEnd: (_) => updatePreview(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LUNA PRO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed:
                original == null || busy ? null : reset,
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onPressed: original == null || busy
                ? null
                : exportPhoto,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF090A0D),
              child: preview == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: pickPhoto,
                        icon: const Icon(
                          Icons.add_photo_alternate,
                        ),
                        label: const Text(
                          'Choose a photo',
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: Image.memory(
                            preview!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                        if (busy)
                          const Center(
                            child:
                                CircularProgressIndicator(),
                          ),
                      ],
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF191A22),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LIGHT & COLOR',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: Color(0xFFB89AFF),
                  ),
                ),
                const SizedBox(height: 12),
                buildSlider(
                  'Brightness',
                  brightness,
                  (value) => brightness = value,
                ),
                buildSlider(
                  'Contrast',
                  contrast,
                  (value) => contrast = value,
                ),
                buildSlider(
                  'Saturation',
                  saturation,
                  (value) => saturation = value,
                ),
                TextButton.icon(
                  onPressed: busy ? null : pickPhoto,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
