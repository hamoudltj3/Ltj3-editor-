
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const Ltj3App());

class Look {
  final String name;
  final double light, contrast, saturation, warm, fade;

  const Look(
    this.name,
    this.light,
    this.contrast,
    this.saturation,
    this.warm,
    this.fade,
  );
}

const looks = <Look>[
  Look('أصلي', 0, 0, 0, 0, 0),
  Look('حرير', .035, -.07, -.07, .025, .045),
  Look('سينما', -.02, .10, -.12, -.015, .035),
  Look('ذهبي', .02, .03, .06, .085, .015),
  Look('ثلج', .025, .025, -.10, -.08, .01),
  Look('ليلي', -.055, .07, -.14, -.03, .03),
  Look('قديم', .015, -.06, -.24, .045, .09),
  Look('حالم', .05, -.09, -.06, .03, .07),
  Look('نقي', .025, .05, .025, -.01, 0),
  Look('مات', -.015, -.03, -.07, 0, .12),
  Look('أبيض وأسود', .01, .055, -1, 0, .025),
];

class Ltj3App extends StatelessWidget {
  const Ltj3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LTJ3 EDITOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xff090909),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff101010),
          foregroundColor: Colors.white,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.white,
          thumbColor: Colors.white,
          inactiveTrackColor: Color(0xff444444),
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
  Uint8List? source;
  Uint8List? preview;

  int look = 0;
  int turns = 0;
  int revision = 0;

  double strength = 1;
  double light = 0;
  double contrast = 0;
  double saturation = 0;
  double temperature = 0;
  double shadows = 0;
  double highlights = 0;

  bool busy = false;
  String tab = 'filters';

  double bounded(double x, double lo, double hi) {
    return x.clamp(lo, hi).toDouble();
  }

  void notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> openPhoto() async {
    if (busy) return;

    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (f == null) return;

      final bytes = await f.readAsBytes();

      if (!mounted) return;

      setState(() {
        source = bytes;
        preview = bytes;
        _resetSettings();
      });

      await updatePreview();
    } catch (_) {
      notice('ما قدرنا نفتح الصورة. جرّبي JPG أو PNG.');
    }
  }

  void _resetSettings() {
    look = 0;
    turns = 0;
    strength = 1;
    light = 0;
    contrast = 0;
    saturation = 0;
    temperature = 0;
    shadows = 0;
    highlights = 0;
  }

  Future<void> reset() async {
    if (source == null || busy) return;

    setState(_resetSettings);
    await updatePreview();
  }

  im.Image render(
    Uint8List input, {
    required bool small,
  }) {
    var image = im.decodeImage(input);

    if (image == null) {
      throw StateError('Unsupported image');
    }

    image = im.bakeOrientation(image);

    if (small && image.width > 900) {
      image = im.copyResize(image, width: 900);
    }

    final p = looks[look];

    final b = bounded(
      light + p.light * strength,
      -.30,
      .30,
    );

    final c = bounded(
      1 + contrast + p.contrast * strength,
      .60,
      1.40,
    );

    final s = bounded(
      1 + saturation + p.saturation * strength,
      0,
      1.65,
    );

    final w = bounded(
      temperature + p.warm * strength,
      -.18,
      .18,
    );

    final fade = bounded(
      p.fade * strength,
      0,
      .18,
    );

    for (final px in image) {
      double r = px.r.toDouble() / 255;
      double g = px.g.toDouble() / 255;
      double bl = px.b.toDouble() / 255;

      r = bounded(r + b, 0, 1);
      g = bounded(g + b, 0, 1);
      bl = bounded(bl + b, 0, 1);

      final lum = .2126 * r + .7152 * g + .0722 * bl;

      final shadowMask =
          math.pow(1 - lum, 2).toDouble();

      final hiMask =
          math.pow(lum, 2).toDouble();

      final local =
          shadows * shadowMask * .25 -
          highlights * hiMask * .25;

      r += local + w * .28;
      g += local;
      bl += local - w * .28;

      r = (r - .5) * c + .5;
      g = (g - .5) * c + .5;
      bl = (bl - .5) * c + .5;

      final gray =
          .2126 * r + .7152 * g + .0722 * bl;

      r = gray + (r - gray) * s;
      g = gray + (g - gray) * s;
      bl = gray + (bl - gray) * s;

      px.r = (
        bounded(
          r * (1 - fade) + fade * .09,
          0,
          1,
        ) * 255
      ).round();

      px.g = (
        bounded(
          g * (1 - fade) + fade * .09,
          0,
          1,
        ) * 255
      ).round();

      px.b = (
        bounded(
          bl * (1 - fade) + fade * .09,
          0,
          1,
        ) * 255
      ).round();
    }

    if (turns != 0) {
      image = im.copyRotate(
        image,
        angle: turns * 90,
      );
    }

    return image;
  }

  Future<void> updatePreview() async {
    if (source == null) return;

    final id = ++revision;

    if (busy) return;

    setState(() => busy = true);

    try {
      final edited = render(
        source!,
        small: true,
      );

      final bytes = Uint8List.fromList(
        im.encodeJpg(edited, quality: 88),
      );

      if (mounted && id == revision) {
        setState(() => preview = bytes);
      }
    } catch (_) {
      notice('صار خطأ بمعالجة الصورة');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (source == null || busy) return;

    setState(() => busy = true);

    try {
      final edited = render(
        source!,
        small: false,
      );

      final bytes = Uint8List.fromList(
        im.encodeJpg(edited, quality: 95),
      );

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/jpeg',
            name: 'LTJ3_EDIT.jpg',
          ),
        ],
        fileNameOverrides: ['LTJ3_EDIT.jpg'],
      );
    } catch (_) {
      notice('الحفظ ما نجح. جربي من Safari.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget control(
    String name,
    double value,
    double min,
    double max,
    ValueChanged<double> apply,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: bounded(value, min, max),
          min: min,
          max: max,
          onChanged: busy
              ? null
              : (v) => setState(() => apply(v)),
          onChangeEnd: (_) => updatePreview(),
        ),
      ],
    );
  }

  Widget presetPanel() {
    return Column(
      children: [
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            itemCount: looks.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(looks[i].name),
              selected: look == i,
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: look == i
                    ? Colors.black
                    : Colors.white,
              ),
              onSelected: busy
                  ? null
                  : (_) async {
                      setState(() => look = i);
                      await updatePreview();
                    },
            ),
          ),
        ),
        control(
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
        control(
          'الإضاءة',
          light,
          -.25,
          .25,
          (v) => light = v,
        ),
        control(
          'التباين',
          contrast,
          -.35,
          .35,
          (v) => contrast = v,
        ),
        control(
          'الظلال',
          shadows,
          -1,
          1,
          (v) => shadows = v,
        ),
        control(
          'الإضاءات العالية',
          highlights,
          -1,
          1,
          (v) => highlights = v,
        ),
      ],
    );
  }

  Widget colorPanel() {
    return Column(
      children: [
        control(
          'التشبع',
          saturation,
          -1,
          .55,
          (v) => saturation = v,
        ),
        control(
          'الحرارة',
          temperature,
          -.15,
          .15,
          (v) => temperature = v,
        ),
      ],
    );
  }

  Widget toolsPanel() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'تدوير الصورة',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        turns = (turns + 3) % 4;
                      });
                      await updatePreview();
                    },
              icon: const Icon(
                Icons.rotate_left,
              ),
              label: const Text('يسار'),
            ),
            const SizedBox(width: 15),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        turns = (turns + 1) % 4;
                      });
                      await updatePreview();
                    },
              icon: const Icon(
                Icons.rotate_right,
              ),
              label: const Text('يمين'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'محو الخلفية الذكي رح نضيفه بمرحلة مستقلة؛ المحو القديم كان يشوّه الألوان.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget tabButton(
    String id,
    String title,
    IconData icon,
  ) {
    return TextButton.icon(
      onPressed: () => setState(() => tab = id),
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: TextButton.styleFrom(
        foregroundColor: tab == id
            ? Colors.white
            : Colors.white54,
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
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط',
            icon: const Icon(
              Icons.restart_alt,
            ),
            onPressed: source == null || busy
                ? null
                : reset,
          ),
          IconButton(
            tooltip: 'حفظ',
            icon: const Icon(
              Icons.ios_share,
            ),
            onPressed: source == null || busy
                ? null
                : save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xff050505),
              child: preview == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: openPhoto,
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
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
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
              color: Color(0xff171717),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      tabButton(
                        'filters',
                        'الفلاتر',
                        Icons.auto_awesome,
                      ),
                      tabButton(
                        'light',
                        'الإضاءة',
                        Icons.wb_sunny_outlined,
                      ),
                      tabButton(
                        'color',
                        'الألوان',
                        Icons.palette_outlined,
                      ),
                      tabButton(
                        'tools',
                        'الأدوات',
                        Icons.tune,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 210,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 12,
                      ),
                      child: tab == 'filters'
                          ? presetPanel()
                          : tab == 'light'
                              ? lightPanel()
                              : tab == 'color'
                                  ? colorPanel()
                                  : toolsPanel(),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : openPhoto,
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
