
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const Ltj3EditorApp());

class Ltj3EditorApp extends StatelessWidget {
  const Ltj3EditorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LTJ3 EDITOR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xff0d0d12),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffcbb6ff),
            brightness: Brightness.dark,
          ),
        ),
        home: const EditorScreen(),
      );
}

class Preset {
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final double gamma;
  final double hue;

  const Preset(
    this.name,
    this.brightness,
    this.contrast,
    this.saturation,
    this.gamma,
    this.hue,
  );
}

const presets = <Preset>[
  Preset('أصلي', 1, 1, 1, 1, 0),
  Preset('حرير', 1.08, .91, .88, .93, 0),
  Preset('غروب', 1.03, 1.10, 1.17, 1, -9),
  Preset('سينما', .92, 1.22, .79, 1.04, -4),
  Preset('ثلج', 1.08, 1.05, .89, 1, 12),
  Preset('ذهبي', 1.07, 1.12, 1.12, .97, -13),
  Preset('حالم', 1.13, .82, .92, .89, 6),
  Preset('ليلي', .76, 1.25, .83, 1.10, 9),
  Preset('نابض', 1.03, 1.16, 1.43, .98, 0),
  Preset('قديم', 1.02, .87, .61, 1.06, -15),
  Preset('أبيض وأسود', 1, 1.18, 0, 1, 0),
];

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Uint8List? original;
  Uint8List? preview;

  int presetIndex = 0;
  int quarterTurns = 0;

  double strength = 1;
  double brightness = 1;
  double contrast = 1;
  double saturation = 1;
  double gamma = 1;
  double hue = 0;
  double exposure = 0;
  double backgroundTolerance = 45;

  bool removeFlatBackground = false;
  bool busy = false;

  String tool = 'filters';

  void toast(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> choose() async {
    if (busy) return;

    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (x == null) return;

      final bytes = await x.readAsBytes();
      if (!mounted) return;

      setState(() {
        original = bytes;
        preview = bytes;
        _resetValues();
      });

      await refresh();
    } catch (_) {
      toast('تعذر فتح الصورة. جربي JPG أو PNG');
    }
  }

  void _resetValues() {
    presetIndex = 0;
    strength = 1;
    brightness = 1;
    contrast = 1;
    saturation = 1;
    gamma = 1;
    hue = 0;
    exposure = 0;
    backgroundTolerance = 45;
    removeFlatBackground = false;
    quarterTurns = 0;
  }

  Future<void> reset() async {
    if (original == null || busy) return;

    setState(_resetValues);
    await refresh();
  }

  img.Image render(
    Uint8List bytes, {
    required bool small,
  }) {
    var picture = img.decodeImage(bytes);

    if (picture == null) {
      throw StateError('Unsupported format');
    }

    picture = img.bakeOrientation(picture);

    if (small && picture.width > 950) {
      picture = img.copyResize(
        picture,
        width: 950,
      );
    }

    final selected = presets[presetIndex];
    final f = strength;

    picture = img.adjustColor(
      picture,
      brightness: brightness *
          (1 + (selected.brightness - 1) * f),
      contrast: contrast *
          (1 + (selected.contrast - 1) * f),
      saturation: saturation *
          (1 + (selected.saturation - 1) * f),
      gamma: gamma *
          (1 + (selected.gamma - 1) * f),
      hue: hue + selected.hue * f,
      exposure: exposure,
    );

    if (quarterTurns != 0) {
      picture = img.copyRotate(
        picture,
        angle: quarterTurns * 90,
      );
    }

    if (removeFlatBackground) {
      picture = picture.convert(numChannels: 4);

      final corner = picture.getPixel(0, 0);
      final r0 = corner.r.toDouble();
      final g0 = corner.g.toDouble();
      final b0 = corner.b.toDouble();

      for (final p in picture) {
        final distance = math.sqrt(
          math.pow(p.r - r0, 2) +
              math.pow(p.g - g0, 2) +
              math.pow(p.b - b0, 2),
        );

        if (distance < backgroundTolerance) {
          p.a = 0;
        }
      }
    }

    return picture;
  }

  Future<void> refresh() async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final edited = render(
        original!,
        small: true,
      );

      final bytes = Uint8List.fromList(
        img.encodePng(edited),
      );

      if (mounted) {
        setState(() => preview = bytes);
      }
    } catch (_) {
      toast('صار خطأ أثناء تعديل الصورة');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> export() async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final edited = render(
        original!,
        small: false,
      );

      final png = removeFlatBackground;

      final data = Uint8List.fromList(
        png
            ? img.encodePng(edited)
            : img.encodeJpg(edited, quality: 95),
      );

      await Share.shareXFiles(
        [
          XFile.fromData(
            data,
            mimeType: png
                ? 'image/png'
                : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [
          png
              ? 'ltj3_edit.png'
              : 'ltj3_edit.jpg',
        ],
      );
    } catch (_) {
      toast('تعذر تصدير الصورة');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget setting(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
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
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  color: Color(0xffcbb6ff),
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: busy
              ? null
              : (v) => setState(() => change(v)),
          onChangeEnd: (_) => refresh(),
        ),
      ],
    );
  }

  Widget filtersPanel() {
    return Column(
      children: [
        const Text(
          'فلاتر LTJ3 الخاصة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            itemCount: presets.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(presets[i].name),
              selected: i == presetIndex,
              onSelected: busy
                  ? null
                  : (_) async {
                      setState(() => presetIndex = i);
                      await refresh();
                    },
            ),
          ),
        ),
        setting(
          'قوة الفلتر',
          strength,
          0,
          1,
          (v) => strength = v,
        ),
      ],
    );
  }

  Widget lightPanel() {
    return Column(
      children: [
        setting(
          'الإضاءة',
          brightness,
          .3,
          2,
          (v) => brightness = v,
        ),
        setting(
          'التباين',
          contrast,
          0,
          2,
          (v) => contrast = v,
        ),
        setting(
          'التعريض',
          exposure,
          -1.5,
          1.5,
          (v) => exposure = v,
        ),
        setting(
          'جاما',
          gamma,
          .5,
          1.8,
          (v) => gamma = v,
        ),
      ],
    );
  }

  Widget colorPanel() {
    return Column(
      children: [
        setting(
          'تشبع الألوان',
          saturation,
          0,
          2,
          (v) => saturation = v,
        ),
        setting(
          'درجة اللون',
          hue,
          -45,
          45,
          (v) => hue = v,
        ),
      ],
    );
  }

  Widget toolsPanel() {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        quarterTurns =
                            (quarterTurns + 3) % 4;
                      });
                      await refresh();
                    },
              icon: const Icon(
                Icons.rotate_left,
              ),
              label: const Text('يسار'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        quarterTurns =
                            (quarterTurns + 1) % 4;
                      });
                      await refresh();
                    },
              icon: const Icon(
                Icons.rotate_right,
              ),
              label: const Text('يمين'),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text(
            'محو خلفية بلون مشابه',
          ),
          subtitle: const Text(
            'تجريبي للخلفيات السادة فقط، مش AI',
          ),
          value: removeFlatBackground,
          onChanged: busy
              ? null
              : (v) async {
                  setState(() {
                    removeFlatBackground = v;
                  });
                  await refresh();
                },
        ),
        if (removeFlatBackground)
          setting(
            'حساسية المحو',
            backgroundTolerance,
            5,
            140,
            (v) => backgroundTolerance = v,
          ),
      ],
    );
  }

  Widget toolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          editorTab(
            'filters',
            'الفلاتر',
            Icons.auto_awesome,
          ),
          editorTab(
            'light',
            'الإضاءة',
            Icons.wb_sunny_outlined,
          ),
          editorTab(
            'color',
            'الألوان',
            Icons.palette_outlined,
          ),
          editorTab(
            'tools',
            'الأدوات',
            Icons.tune,
          ),
        ],
      ),
    );
  }

  Widget editorTab(
    String id,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: TextButton.icon(
        onPressed: () {
          setState(() => tool = id);
        },
        icon: Icon(icon),
        label: Text(title),
        style: TextButton.styleFrom(
          foregroundColor: tool == id
              ? const Color(0xffd4c0ff)
              : Colors.white70,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط',
            onPressed:
                original == null || busy ? null : reset,
            icon: const Icon(
              Icons.restart_alt,
            ),
          ),
          IconButton(
            tooltip: 'تصدير',
            onPressed:
                original == null || busy ? null : export,
            icon: const Icon(
              Icons.ios_share,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xff08080b),
              child: preview == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: choose,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                        ),
                        label: const Text(
                          'اختاري صورة',
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          minScale: .5,
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
            decoration: const BoxDecoration(
              color: Color(0xff1b1a23),
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                toolbar(),
                SizedBox(
                  height: 205,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                      ),
                      child: tool == 'filters'
                          ? filtersPanel()
                          : tool == 'light'
                              ? lightPanel()
                              : tool == 'color'
                                  ? colorPanel()
                                  : toolsPanel(),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : choose,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: const Text(
                    'تغيير الصورة',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
