
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const Ltj3App());

const bg = Color(0xFF090909);
const panel = Color(0xFF191919);
const tile = Color(0xFF292929);

class Filter {
  final String name;
  final double light;
  final double contrast;
  final double saturation;
  final double warmth;
  final double fade;

  const Filter(
    this.name,
    this.light,
    this.contrast,
    this.saturation,
    this.warmth,
    this.fade,
  );
}

const filters = [
  Filter('LTJ3 01', .03, .04, .05, .03, 0),
  Filter('LTJ3 02', -.02, .12, -.12, -.02, .01),
  Filter('LTJ3 03', .04, .04, .08, .07, 0),
  Filter('LTJ3 04', .03, -.05, -.12, -.06, .04),
  Filter('LTJ3 05', -.05, .09, -.08, -.03, .02),
  Filter('LTJ3 06', .04, -.08, -.08, .04, .07),
  Filter('LTJ3 07', 0, .07, .12, .02, 0),
  Filter('LTJ3 08', .02, -.07, -.30, .05, .09),
  Filter('LTJ3 09', .02, .11, -1, 0, .01),
  Filter('LTJ3 10', -.03, .08, -.15, .06, .05),
];

class Settings {
  int selected = -1;
  int rotation = 0;
  bool flip = false;

  String ratio = 'Free';

  double strength = 1;
  double exposure = 0;
  double contrast = 0;
  double shadows = 0;
  double highlights = 0;
  double blacks = 0;
  double whites = 0;
  double midtones = 0;
  double temperature = 0;
  double tint = 0;
  double saturation = 0;
  double vibrance = 0;
  double clarity = 0;
  double sharpen = 0;
  double smooth = 0;
  double vignette = 0;
  double grain = 0;
  double fade = 0;

  List<double> hue = List.filled(8, 0);
  List<double> hslSaturation = List.filled(8, 0);
  List<double> luminance = List.filled(8, 0);

  Settings copy() {
    final x = Settings()
      ..selected = selected
      ..rotation = rotation
      ..flip = flip
      ..ratio = ratio
      ..strength = strength
      ..exposure = exposure
      ..contrast = contrast
      ..shadows = shadows
      ..highlights = highlights
      ..blacks = blacks
      ..whites = whites
      ..midtones = midtones
      ..temperature = temperature
      ..tint = tint
      ..saturation = saturation
      ..vibrance = vibrance
      ..clarity = clarity
      ..sharpen = sharpen
      ..smooth = smooth
      ..vignette = vignette
      ..grain = grain
      ..fade = fade;

    x.hue = List.of(hue);
    x.hslSaturation = List.of(hslSaturation);
    x.luminance = List.of(luminance);

    return x;
  }
}

double limit(double n, double low, double high) {
  return n.clamp(low, high).toDouble();
}

img.Image resizeForPreview(img.Image image, int maxSize) {
  if (math.max(image.width, image.height) <= maxSize) {
    return image;
  }

  if (image.width >= image.height) {
    return img.copyResize(image, width: maxSize);
  }

  return img.copyResize(image, height: maxSize);
}

List<double> toHsl(double r, double g, double b) {
  final maximum = math.max(r, math.max(g, b));
  final minimum = math.min(r, math.min(g, b));
  final d = maximum - minimum;

  double h = 0;
  double s = 0;

  final l = (maximum + minimum) / 2;

  if (d > .00001) {
    final divisor = 1 - (2 * l - 1).abs();
    s = divisor == 0 ? 0 : d / divisor;

    if (maximum == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (maximum == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
  }

  return [
    (h + 360) % 360,
    limit(s, 0, 1),
    limit(l, 0, 1),
  ];
}

List<double> fromHsl(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - (((h / 60) % 2) - 1).abs());
  final m = l - c / 2;

  double r = 0;
  double g = 0;
  double b = 0;

  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }

  return [r + m, g + m, b + m];
}

img.Image process(img.Image original, Settings e) {
  final preset =
      e.selected >= 0 ? filters[e.selected] : null;

  final exposure = limit(
    e.exposure + (preset?.light ?? 0) * e.strength,
    -.6,
    .6,
  );

  final contrast = limit(
    1 + e.contrast +
        (preset?.contrast ?? 0) * e.strength,
    .55,
    1.5,
  );

  final saturation = limit(
    1 + e.saturation +
        (preset?.saturation ?? 0) * e.strength,
    0,
    1.7,
  );

  final warmth = limit(
    e.temperature +
        (preset?.warmth ?? 0) * e.strength,
    -.2,
    .2,
  );

  final fading = limit(
    e.fade + (preset?.fade ?? 0) * e.strength,
    0,
    .25,
  );

  var output = original.convert(
    format: img.Format.uint8,
    numChannels: 3,
  );

  final cx = (output.width - 1) / 2;
  final cy = (output.height - 1) / 2;

  for (final p in output) {
    double r = p.r / 255;
    double g = p.g / 255;
    double b = p.b / 255;

    final lum = limit(
      .2126 * r + .7152 * g + .0722 * b,
      0,
      1,
    );

    final shadowWeight = math.pow(1 - lum, 2);
    final highlightWeight = math.pow(lum, 2);
    final midWeight = 1 - (2 * lum - 1).abs();

    final tone =
        e.shadows * shadowWeight * .20 +
        e.highlights * highlightWeight * .20 +
        e.blacks * shadowWeight * .12 +
        e.whites * highlightWeight * .12 +
        e.midtones * midWeight * .12;

    final gain = math.pow(2, exposure).toDouble();

    r = (r * gain +
            tone +
            warmth * .27 +
            e.tint * .13 -
            .5) *
        contrast +
        .5;

    g = (g * gain +
            tone -
            e.tint * .10 -
            .5) *
        contrast +
        .5;

    b = (b * gain +
            tone -
            warmth * .27 +
            e.tint * .13 -
            .5) *
        contrast +
        .5;

    final gray =
        .2126 * r + .7152 * g + .0722 * b;

    final spread =
        math.max(r, math.max(g, b)) -
        math.min(r, math.min(g, b));

    final sat = limit(
      saturation +
          e.vibrance * (1 - spread.abs()) * .35,
      0,
      1.8,
    );

    r = gray + (r - gray) * sat;
    g = gray + (g - gray) * sat;
    b = gray + (b - gray) * sat;

    final hsl = toHsl(
      limit(r, 0, 1),
      limit(g, 0, 1),
      limit(b, 0, 1),
    );

    final index = ((hsl[0] / 45).round()) % 8;

    final adjusted = fromHsl(
      (hsl[0] + e.hue[index] * 40 + 360) % 360,
      limit(
        hsl[1] * (1 + e.hslSaturation[index]),
        0,
        1,
      ),
      limit(
        hsl[2] + e.luminance[index] * .2,
        0,
        1,
      ),
    );

    r = adjusted[0];
    g = adjusted[1];
    b = adjusted[2];

    r = r * (1 - fading) + fading * .5;
    g = g * (1 - fading) + fading * .5;
    b = b * (1 - fading) + fading * .5;

    final dx = cx == 0 ? 0.0 : (p.x - cx) / cx;
    final dy = cy == 0 ? 0.0 : (p.y - cy) / cy;

    final distance = limit(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0,
      1,
    );

    final edge = math.pow(distance, 1.7);

    final vignette =
        1 - e.vignette * edge * .65;

    r *= vignette;
    g *= vignette;
    b *= vignette;

    if (e.grain > 0) {
      final noise = math.sin(
        p.x * 12.9898 + p.y * 78.233,
      ) * 43758.5453;

      final n = (noise - noise.floor() - .5) *
          e.grain *
          .18;

      r += n;
      g += n;
      b += n;
    }

    p.r = (limit(r, 0, 1) * 255).round();
    p.g = (limit(g, 0, 1) * 255).round();
    p.b = (limit(b, 0, 1) * 255).round();
  }

  final sharp = limit(
    e.sharpen * .6 + e.clarity * .2,
    0,
    .8,
  );

  if (sharp > .01) {
    final blurred = img.gaussianBlur(
      output,
      radius: 1,
    );

    for (final p in output) {
      final q = blurred.getPixel(p.x, p.y);

      p.r = limit(
        p.r + (p.r - q.r) * sharp,
        0,
        255,
      ).round();

      p.g = limit(
        p.g + (p.g - q.g) * sharp,
        0,
        255,
      ).round();

      p.b = limit(
        p.b + (p.b - q.b) * sharp,
        0,
        255,
      ).round();
    }
  }

  if (e.smooth > .01) {
    final blurred = img.gaussianBlur(
      output,
      radius: 1,
    );

    final mix = e.smooth * .4;

    for (final p in output) {
      final q = blurred.getPixel(p.x, p.y);

      p.r = (p.r * (1 - mix) + q.r * mix).round();
      p.g = (p.g * (1 - mix) + q.g * mix).round();
      p.b = (p.b * (1 - mix) + q.b * mix).round();
    }
  }

  if (e.flip) {
    output = img.flipHorizontal(output);
  }

  if (e.rotation != 0) {
    output = img.copyRotate(
      output,
      angle: e.rotation * 90,
    );
  }

  final ratios = {
    '1:1': 1.0,
    '4:5': .8,
    '3:4': .75,
    '9:16': 9 / 16,
    '16:9': 16 / 9,
  };

  final ratio = ratios[e.ratio];

  if (ratio != null) {
    int width = output.width;
    int height = output.height;

    if (width / height > ratio) {
      width = math.max(1, (height * ratio).round());
    } else {
      height = math.max(1, (width / ratio).round());
    }

    output = img.copyCrop(
      output,
      x: (output.width - width) ~/ 2,
      y: (output.height - height) ~/ 2,
      width: width,
      height: height,
    );
  }

  return output;
}

class Ltj3App extends StatelessWidget {
  const Ltj3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LTJ3 EDITOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: panel,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.white,
          inactiveTrackColor: Color(0xFF424242),
          thumbColor: Colors.white,
          trackHeight: 3,
        ),
      ),
      home: const Editor(),
    );
  }
}

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final picker = ImagePicker();

  final List<Uint8List> gallery = [];
  final List<Settings> undoHistory = [];
  final List<Settings> redoHistory = [];

  Uint8List? source;
  Uint8List? preview;
  Uint8List? originalPreview;

  img.Image? originalImage;
  img.Image? previewBase;

  List<Uint8List?> thumbnails =
      List.filled(11, null);

  Settings edit = Settings();

  bool showingGallery = true;
  bool busy = false;
  bool comparing = false;

  String tab = 'Looks';
  int hslMode = 0;

  int revision = 0;
  Settings? dragStart;

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void saveHistory() {
    undoHistory.add(edit.copy());

    if (undoHistory.length > 30) {
      undoHistory.removeAt(0);
    }

    redoHistory.clear();
  }

  void change(VoidCallback action) {
    if (busy || originalImage == null) return;

    saveHistory();

    setState(action);
    refresh();
  }

  void undo() {
    if (undoHistory.isEmpty || busy) return;

    redoHistory.add(edit.copy());

    setState(() {
      edit = undoHistory.removeLast();
    });

    refresh();
  }

  void redo() {
    if (redoHistory.isEmpty || busy) return;

    undoHistory.add(edit.copy());

    setState(() {
      edit = redoHistory.removeLast();
    });

    refresh();
  }

  Future<void> importPhotos() async {
    if (busy) return;

    try {
      final files = await picker.pickMultiImage(
        imageQuality: 90,
      );

      if (files.isEmpty) return;

      final images = <Uint8List>[];

      for (final file in files) {
        images.add(await file.readAsBytes());
      }

      if (!mounted) return;

      setState(() {
        gallery.addAll(images);
      });

      if (source == null) {
        await openPhoto(images.first);
      }
    } catch (_) {
      message('Could not import photos.');
    }
  }

  Future<void> openPhoto(Uint8List bytes) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      var decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unsupported image');
      }

      decoded = img.bakeOrientation(decoded);

      final base = resizeForPreview(decoded, 850);

      final tiny = resizeForPreview(decoded, 180);

      final thumbs = <Uint8List?>[
        Uint8List.fromList(
          img.encodeJpg(tiny, quality: 75),
        ),
      ];

      for (int i = 0; i < filters.length; i++) {
        final settings = Settings()
          ..selected = i;

        final result = process(tiny, settings);

        thumbs.add(
          Uint8List.fromList(
            img.encodeJpg(result, quality: 74),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        source = bytes;
        originalImage = decoded;
        previewBase = base;
        originalPreview = Uint8List.fromList(
          img.encodeJpg(base, quality: 90),
        );
        preview = originalPreview;
        thumbnails = thumbs;
        edit = Settings();
        undoHistory.clear();
        redoHistory.clear();
        showingGallery = false;
        tab = 'Looks';
      });
    } catch (_) {
      message('Unable to open photo.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> refresh() async {
    if (previewBase == null) return;

    final id = ++revision;
    final snapshot = edit.copy();

    if (busy) return;

    setState(() => busy = true);

    try {
      final result = process(
        previewBase!,
        snapshot,
      );

      final data = Uint8List.fromList(
        img.encodeJpg(result, quality: 91),
      );

      if (!mounted) return;

      if (id == revision) {
        setState(() {
          preview = data;
        });
      }
    } catch (_) {
      message('Preview error.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }

      if (id != revision && mounted) {
        refresh();
      }
    }
  }

  Future<void> export() async {
    if (originalImage == null || busy) return;

    setState(() => busy = true);

    try {
      final result = process(
        originalImage!,
        edit.copy(),
      );

      final data = Uint8List.fromList(
        img.encodeJpg(result, quality: 95),
      );

      await Share.shareXFiles(
        [
          XFile.fromData(
            data,
            mimeType: 'image/jpeg',
            name: 'LTJ3_EDIT.jpg',
          ),
        ],
        fileNameOverrides: [
          'LTJ3_EDIT.jpg',
        ],
      );
    } catch (_) {
      message('Export failed. Try Safari.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget pill(
    String label, {
    required bool selected,
    required VoidCallback tap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF393939)
              : tile,
          foregroundColor: selected
              ? Colors.white
              : Colors.white60,
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 12,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }

  Widget slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> update,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: limit(value, min, max),
              onChangeStart: (_) {
                dragStart = edit.copy();
              },
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => update(v));
                    },
              onChangeEnd: (_) {
                if (dragStart != null) {
                  undoHistory.add(dragStart!);
                  redoHistory.clear();
                  dragStart = null;
                }
                refresh();
              },
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget looksPanel() {
    return Column(
      children: [
        SizedBox(
          height: 122,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            itemCount: 11,
            itemBuilder: (context, index) {
              final selected = edit.selected == index - 1;
              final name = index == 0
                  ? 'ORIGINAL'
                  : filters[index - 1].name;

              return GestureDetector(
                onTap: () {
                  change(() {
                    edit.selected = index - 1;
                  });
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 9),
                  child: Column(
                    children: [
                      Container(
                        height: 86,
                        decoration: BoxDecoration(
                          color: tile,
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius:
                              BorderRadius.circular(7),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: thumbnails[index] == null
                            ? const Center(
                                child: Icon(Icons.image),
                              )
                            : Image.memory(
                                thumbnails[index]!,
                                width: 90,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        slider(
          'Strength',
          edit.strength,
          0,
          1,
          (v) => edit.strength = v,
        ),
      ],
    );
  }

  Widget lightPanel() {
    return Column(
      children: [
        slider('Exposure', edit.exposure, -.4, .4,
            (v) => edit.exposure = v),
        slider('Contrast', edit.contrast, -.35, .35,
            (v) => edit.contrast = v),
        slider('Blacks', edit.blacks, -1, 1,
            (v) => edit.blacks = v),
        slider('Shadows', edit.shadows, -1, 1,
            (v) => edit.shadows = v),
        slider('Midtones', edit.midtones, -1, 1,
            (v) => edit.midtones = v),
        slider('Highlights', edit.highlights, -1, 1,
            (v) => edit.highlights = v),
        slider('Whites', edit.whites, -1, 1,
            (v) => edit.whites = v),
      ],
    );
  }

  Widget colorPanel() {
    return Column(
      children: [
        slider('Temperature', edit.temperature, -.18, .18,
            (v) => edit.temperature = v),
        slider('Tint', edit.tint, -.18, .18,
            (v) => edit.tint = v),
        slider('Saturation', edit.saturation, -1, .6,
            (v) => edit.saturation = v),
        slider('Vibrance', edit.vibrance, -1, 1,
            (v) => edit.vibrance = v),
      ],
    );
  }

  Widget hslPanel() {
    const colors = [
      Color(0xFFB52F37),
      Color(0xFFBA812E),
      Color(0xFF8EAA31),
      Color(0xFF2B9655),
      Color(0xFF32A8A7),
      Color(0xFF3B62C2),
      Color(0xFF8050B2),
      Color(0xFFAD418E),
    ];

    final values = hslMode == 0
        ? edit.hue
        : hslMode == 1
            ? edit.hslSaturation
            : edit.luminance;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              pill(
                ['Hue', 'Saturation', 'Luminance'][i],
                selected: hslMode == i,
                tap: () {
                  setState(() => hslMode = i);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: Row(
            children: [
              for (int i = 0; i < 8; i++)
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 7,
                        backgroundColor: colors[i],
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: values[i],
                            min: -1,
                            max: 1,
                            activeColor: colors[i],
                            onChangeStart: (_) {
                              dragStart = edit.copy();
                            },
                            onChanged: busy
                                ? null
                                : (v) {
                                    setState(() {
                                      values[i] = v;
                                    });
                                  },
                            onChangeEnd: (_) {
                              if (dragStart != null) {
                                undoHistory.add(dragStart!);
                                redoHistory.clear();
                                dragStart = null;
                              }
                              refresh();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget detailsPanel() {
    return Column(
      children: [
        slider('Clarity', edit.clarity, 0, 1,
            (v) => edit.clarity = v),
        slider('Sharpen', edit.sharpen, 0, 1,
            (v) => edit.sharpen = v),
        slider('Noise Smooth', edit.smooth, 0, 1,
            (v) => edit.smooth = v),
      ],
    );
  }

  Widget effectsPanel() {
    return Column(
      children: [
        slider('Vignette', edit.vignette, -.75, 1,
            (v) => edit.vignette = v),
        slider('Grain', edit.grain, 0, 1,
            (v) => edit.grain = v),
        slider('Fade', edit.fade, 0, .25,
            (v) => edit.fade = v),
      ],
    );
  }

  Widget cropPanel() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'ASPECT RATIO',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: 53,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final r in [
                'Free',
                '1:1',
                '4:5',
                '3:4',
                '9:16',
                '16:9',
              ])
                pill(
                  r,
                  selected: edit.ratio == r,
                  tap: () {
                    change(() => edit.ratio = r);
                  },
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                change(() {
                  edit.rotation =
                      (edit.rotation + 3) % 4;
                });
              },
              icon: const Icon(Icons.rotate_left),
            ),
            const SizedBox(width: 35),
            IconButton(
              onPressed: () {
                change(() {
                  edit.rotation =
                      (edit.rotation + 1) % 4;
                });
              },
              icon: const Icon(Icons.rotate_right),
            ),
            const SizedBox(width: 35),
            IconButton(
              onPressed: () {
                change(() => edit.flip = !edit.flip);
              },
              icon: const Icon(Icons.flip),
            ),
          ],
        ),
      ],
    );
  }

  Widget galleryScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Photos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: importPhotos,
                icon: const Icon(Icons.add),
                label: const Text('Import'),
              ),
            ],
          ),
        ),
        Expanded(
          child: gallery.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 55,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      const Text('Start with your photos'),
                      const SizedBox(height: 15),
                      FilledButton(
                        onPressed: importPhotos,
                        child: const Text('Import Photos'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: gallery.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => openPhoto(gallery[index]),
                      child: Image.memory(
                        gallery[index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget editorScreen() {
    final image = comparing
        ? originalPreview
        : preview;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (_) {
              setState(() => comparing = true);
            },
            onLongPressEnd: (_) {
              setState(() => comparing = false);
            },
            child: Container(
              color: const Color(0xFF050505),
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (image != null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        image,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (comparing)
                    const Positioned(
                      bottom: 18,
                      child: Text(
                        'ORIGINAL',
                        style: TextStyle(
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  if (busy)
                    const Positioned(
                      top: 15,
                      right: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: panel,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final name in [
                      'Looks',
                      'Light',
                      'Color',
                      'HSL',
                      'Details',
                      'Effects',
                      'Crop',
                    ])
                      pill(
                        name,
                        selected: tab == name,
                        tap: () {
                          setState(() => tab = name);
                        },
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 230,
                child: SingleChildScrollView(
                  child: switch (tab) {
                    'Looks' => looksPanel(),
                    'Light' => lightPanel(),
                    'Color' => colorPanel(),
                    'HSL' => hslPanel(),
                    'Details' => detailsPanel(),
                    'Effects' => effectsPanel(),
                    _ => cropPanel(),
                  },
                ),
              ),
              const Divider(
                color: Color(0xFF333333),
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            change(() {
                              edit = Settings();
                            });
                          },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                  const Text(
                    'HOLD TO COMPARE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : export,
                    icon: const Icon(Icons.check),
                    label: const Text('Export'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            showingGallery
                ? Icons.grid_view_rounded
                : Icons.arrow_back_ios_new,
          ),
          onPressed: () {
            setState(() => showingGallery = true);
          },
        ),
        actions: [
          if (!showingGallery)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed:
                  busy || undoHistory.isEmpty ? null : undo,
            ),
          if (!showingGallery)
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed:
                  busy || redoHistory.isEmpty ? null : redo,
            ),
          if (!showingGallery)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: busy ? null : export,
            ),
        ],
      ),
      body: showingGallery
          ? galleryScreen()
          : editorScreen(),
    );
  }
}
