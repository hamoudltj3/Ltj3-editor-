
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const LunaApp());

class LunaApp extends StatelessWidget {
  const LunaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
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

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Uint8List? original;
  Uint8List? preview;
  double brightness = 0;
  double contrast = 1;
  double saturation = 1;
  bool busy = false;

  Future<void> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      original = bytes;
      preview = bytes;
      brightness = 0;
      contrast = 1;
      saturation = 1;
    });
  }

  // Processing is local. Preview is downscaled for responsiveness;
  // export always processes the original resolution.
  Uint8List process(Uint8List bytes, {bool small = false}) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image');
    }
    if (small && decoded.width > 1100) {
      decoded = img.copyResize(decoded, width: 1100);
    }
    final out = img.adjustColor(
      decoded,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
    return Uint8List.fromList(
      img.encodeJpg(out, quality: small ? 82 : 95),
    );
  }

  Future<void> updatePreview() async {
    if (original == null) return;
    setState(() => busy = true);
    try {
      final result = process(original!, small: true);
      if (mounted) {
        setState(() => preview = result);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not process this image'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    if (original == null) return;
    setState(() => busy = true);
    try {
      final bytes = process(original!);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/luna_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Edited with Luna Pro',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget control(
    String name,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                color: Color(0xFFB89AFF),
              ),
            ),
          ],
        ),
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) => setState(() => change(v)),
        onChangeEnd: (_) => updatePreview(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'LUNA  /  STUDIO',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Reset',
          onPressed: original == null ? null : () {
            setState(() {
              brightness = 0;
              contrast = 1;
              saturation = 1;
              preview = original;
            });
          },
          icon: const Icon(Icons.restart_alt),
        ),
        IconButton(
          tooltip: 'Export',
          onPressed: busy || original == null ? null : export,
          icon: const Icon(Icons.ios_share),
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
                      onPressed: pick,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                      ),
                      label: const Text('Choose a photo'),
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
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 14, bottom: 20),
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
              control(
                'Brightness',
                brightness,
                -1,
                1,
                (v) => brightness = v,
              ),
              control(
                'Contrast',
                contrast,
                0,
                2,
                (v) => contrast = v,
              ),
              control(
                'Saturation',
                saturation,
                0,
                2,
                (v) => saturation = v,
              ),
              TextButton.icon(
                onPressed: pick,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change photo'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
