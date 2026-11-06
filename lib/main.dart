
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LTJ3App());
}

const bg = Color(0xFF080808);
const panel = Color(0xFF171717);
const tile = Color(0xFF262626);
const silver = Color(0xFFBDBDBD);

class Preset {
  final String name;
  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double fade;

  const Preset(
    this.name,
    this.exposure,
    this.contrast,
    this.saturation,
    this.temperature,
    this.fade,
  );
}

const presets = <Preset>[
  Preset('LTJ3 01', .02, .06, .07, .02, 0),
  Preset('LTJ3 02', -.05, .10, -.14, -.05, 0),
  Preset('LTJ3 03', .05, .04, .18, .04, 0),
  Preset('LTJ3 04', -.02, -.04, -.22, -.02, .08),
  Preset('LTJ3 05', -.06, .16, -.04, -.05, 0),
  Preset('LTJ3 06', .08, -.09, -.10, .09, .07),
  Preset('LTJ3 07', .02, .11, .21, .02, 0),
  Preset('LTJ3 08', -.01, .06, -.25, -.06, .02),
  Preset('LTJ3 09', .01, .15, -1, 0, 0),
  Preset('LTJ3 10', -.05, .12, -.16, .04, .02),
  Preset('LTJ3 11', .03, .14, .08, .06, 0),
  Preset('LTJ3 12', -.03, -.03, -.32, .09, .12),
  Preset('LTJ3 13', -.06, .08, -.17, -.08, .03),
  Preset('LTJ3 14', .04, .09, .11, .12, .02),
  Preset('LTJ3 15', -.09, .17, -.29, -.09, 0),
  Preset('LTJ3 16', .02, .19, -1, 0, 0),
  Preset('LTJ3 17', -.02, .14, .18, -.06, .01),
  Preset('LTJ3 18', .05, -.06, -.19, .02, .10),
  Preset('LTJ3 19', -.04, .08, -.65, -.04, .03),
  Preset('LTJ3 20', -.03, .20, -.06, .08, 0),
];

class EditData {
  int preset = -1;
  int texture = 0;
  int rotation = 0;
  bool flip = false;

  String ratio = 'Original';

  double strength = 1;
  double exposure = 0;
  double contrast = 0;
  double saturation = 0;
  double temperature = 0;
  double highlights = 0;
  double shadows = 0;
  double fade = 0;
  double vignette = 0;
  double grain = 0;
  double textureStrength = .35;
  double sharpen = 0;

  EditData copy() {
    return EditData()
      ..preset = preset
      ..texture = texture
      ..rotation = rotation
      ..flip = flip
      ..ratio = ratio
      ..strength = strength
      ..exposure = exposure
      ..contrast = contrast
      ..saturation = saturation
      ..temperature = temperature
      ..highlights = highlights
      ..shadows = shadows
      ..fade = fade
      ..vignette = vignette
      ..grain = grain
      ..textureStrength = textureStrength
      ..sharpen = sharpen;
  }
}

double limit(num v, double low, double high) =>
    v.clamp(low, high).toDouble();

img.Image resizePreview(img.Image source, int maximum) {
  final w = source.width;
  final h = source.height;

  if (math.max(w, h) <= maximum) {
    return img.copyResize(
      source,
      width: w,
      height: h,
    );
  }

  if (w >= h) {
    return img.copyResize(source, width: maximum);
  }

  return img.copyResize(source, height: maximum);
}

double randomAt(int x, int y, int seed) {
  final n = math.sin(
    x * 12.9898 + y * 78.233 + seed * 37.719,
  ) * 43758.5453;

  return n - n.floorToDouble();
}

img.Image processPhoto(img.Image source, EditData e) {
  final preset = e.preset < 0 ? null : presets[e.preset];

  final exposure = limit(
    e.exposure +
        (preset?.exposure ?? 0) * e.strength,
    -.7,
    .7,
  );

  final contrast = limit(
    1 +
        e.contrast +
        (preset?.contrast ?? 0) * e.strength,
    .5,
    1.7,
  );

  final saturation = limit(
    1 +
        e.saturation +
        (preset?.saturation ?? 0) * e.strength,
    0,
    2,
  );

  final temperature = limit(
    e.temperature +
        (preset?.temperature ?? 0) * e.strength,
    -.3,
    .3,
  );

  final fade = limit(
    e.fade + (preset?.fade ?? 0) * e.strength,
    0,
    .35,
  );

  final output = source.convert(
    format: img.Format.uint8,
    numChannels: 3,
  );

  final w = output.width;
  final h = output.height;
  final gain = math.pow(2, exposure).toDouble();

  for (final pixel in output) {
    final x = pixel.x;
    final y = pixel.y;

    double r = pixel.r / 255;
    double g = pixel.g / 255;
    double b = pixel.b / 255;

    final luminance =
        .2126 * r + .7152 * g + .0722 * b;

    final shadowWeight =
        math.pow(1 - luminance, 2).toDouble();

    final highlightWeight =
        math.pow(luminance, 2).toDouble();

    final tone =
        e.shadows * shadowWeight * .23 +
        e.highlights * highlightWeight * .23;

    r = ((r * gain + tone + temperature * .20 - .5) *
            contrast) +
        .5;

    g = ((g * gain + tone - .5) * contrast) + .5;

    b = ((b * gain + tone - temperature * .20 - .5) *
            contrast) +
        .5;

    final grey = .2126 * r + .7152 * g + .0722 * b;

    r = grey + (r - grey) * saturation;
    g = grey + (g - grey) * saturation;
    b = grey + (b - grey) * saturation;

    r = r * (1 - fade) + fade * .5;
    g = g * (1 - fade) + fade * .5;
    b = b * (1 - fade) + fade * .5;

    final dx = (x - w / 2) / (w / 2);
    final dy = (y - h / 2) / (h / 2);

    final distance = limit(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0,
      1,
    );

    final edge = math.pow(distance, 1.8).toDouble();

    final vignette =
        1 - e.vignette * edge * .72;

    r *= vignette;
    g *= vignette;
    b *= vignette;

    if (e.grain > 0) {
      final noise =
          (randomAt(x, y, 7) - .5) * e.grain * .13;

      r += noise;
      g += noise;
      b += noise;
    }

    if (e.texture > 0) {
      final amount = e.textureStrength;

      if (e.texture <= 4) {
        final size = e.texture.isEven ? 15 : 23;

        final cellX = x ~/ size;
        final cellY = y ~/ size;

        final chance = randomAt(
          cellX,
          cellY,
          e.texture * 29,
        );

        final px =
            randomAt(cellX, cellY, 43) * size;

        final py =
            randomAt(cellX, cellY, 57) * size;

        if (chance > .975 &&
            ((x % size) - px).abs() < 1.5 &&
            ((y % size) - py).abs() < 1.5) {
          r += amount * .45;
          g += amount * .45;
          b += amount * .45;
        }

        if (e.texture >= 3) {
          final linePosition =
              w * (e.texture == 3 ? .30 : .75);

          if ((x -
                      linePosition -
                      math.sin(y * .02) * 2)
                  .abs() <
              .65) {
            r += amount * .19;
            g += amount * .19;
            b += amount * .19;
          }
        }
      }

      if (e.texture >= 5 && e.texture <= 7) {
        final cx = e.texture == 5
            ? -.18
            : e.texture == 6
                ? 1.18
                : .5;

        final cy = e.texture == 7 ? -.25 : .5;

        final nx = x / w;
        final ny = y / h;

        final d =
            math.pow((nx - cx) * 1.4, 2) +
            math.pow((ny - cy) * 1.4, 2);

        final light =
            math.exp(-d * 5) * amount * .44;

        final rr = e.texture == 7 ? .65 : 1.0;
        final gg = e.texture == 7 ? .65 : .40;
        final bb = e.texture == 7 ? 1.0 : .20;

        r = r * (1 - light) + rr * light;
        g = g * (1 - light) + gg * light;
        b = b * (1 - light) + bb * light;
      }

      if (e.texture >= 8) {
        double glow = 0;

        final count = e.texture == 8 ? 4 : 7;

        for (int i = 0; i < count; i++) {
          final cx = randomAt(i, 2, 30);
          final cy = randomAt(i, 3, 40);

          final radius =
              .03 + randomAt(i, 5, 50) * .06;

          final ddx = x / w - cx;
          final ddy = y / h - cy;

          final dist = math.sqrt(
            ddx * ddx + ddy * ddy,
          );

          glow += limit(
            1 - dist / radius,
            0,
            1,
          ) * .4;
        }

        final mix = limit(
          glow * amount,
          0,
          .35,
        );

        r = r * (1 - mix) + mix;
        g = g * (1 - mix) + mix * .85;
        b = b * (1 - mix) + mix * .70;
      }
    }

    pixel.r = (limit(r, 0, 1) * 255).round();
    pixel.g = (limit(g, 0, 1) * 255).round();
    pixel.b = (limit(b, 0, 1) * 255).round();
  }

  img.Image result = output;

  if (e.sharpen > .01) {
    final blurred = img.gaussianBlur(
      result,
      radius: 1,
    );

    final k = e.sharpen * .65;

    for (final p in result) {
      final q = blurred.getPixel(p.x, p.y);

      p.r = limit(
        p.r + (p.r - q.r) * k,
        0,
        255,
      ).round();

      p.g = limit(
        p.g + (p.g - q.g) * k,
        0,
        255,
      ).round();

      p.b = limit(
        p.b + (p.b - q.b) * k,
        0,
        255,
      ).round();
    }
  }

  if (e.flip) {
    result = img.flipHorizontal(result);
  }

  if (e.rotation != 0) {
    result = img.copyRotate(
      result,
      angle: e.rotation * 90,
    );
  }

  final ratios = <String, double>{
    '1:1': 1,
    '4:5': .8,
    '3:4': .75,
    '9:16': 9 / 16,
    '16:9': 16 / 9,
  };

  if (ratios.containsKey(e.ratio)) {
    final ratio = ratios[e.ratio]!;

    int cw = result.width;
    int ch = result.height;

    if (cw / ch > ratio) {
      cw = (ch * ratio).round();
    } else {
      ch = (cw / ratio).round();
    }

    result = img.copyCrop(
      result,
      x: (result.width - cw) ~/ 2,
      y: (result.height - ch) ~/ 2,
      width: cw,
      height: ch,
    );
  }

  return result;
}

class LTJ3App extends StatelessWidget {
  const LTJ3App({super.key});

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
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: panel,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.white,
          inactiveTrackColor: Color(0xFF444444),
          thumbColor: Colors.white,
          trackHeight: 3,
        ),
      ),
      home: const LTJ3Home(),
    );
  }
}

class LTJ3Home extends StatefulWidget {
  const LTJ3Home({super.key});

  @override
  State<LTJ3Home> createState() => _LTJ3HomeState();
}

class _LTJ3HomeState extends State<LTJ3Home> {
  final picker = ImagePicker();

  bool started = false;
  bool gallery = true;
  bool busy = false;
  bool compare = false;
  bool exportPng = false;

  String section = 'Filters';
  int textureCategory = 0;

  final photos = <Uint8List>[];
  final undoHistory = <EditData>[];
  final redoHistory = <EditData>[];

  img.Image? originalImage;
  img.Image? previewSource;

  Uint8List? previewBytes;
  Uint8List? originalPreview;

  final filterThumbs =
      List<Uint8List?>.filled(21, null);

  final textureThumbs =
      List<Uint8List?>.filled(10, null);

  EditData edit = EditData();
  EditData? sliderStart;

  Timer? previewTimer;

  @override
  void dispose() {
    previewTimer?.cancel();
    super.dispose();
  }

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

  Future<void> importPhotos() async {
    if (busy) return;

    try {
      final files = await picker.pickMultiImage(
        imageQuality: 100,
      );

      if (files.isEmpty) return;

      final loaded = <Uint8List>[];

      for (final file in files) {
        loaded.add(await file.readAsBytes());
      }

      if (!mounted) return;

      setState(() {
        photos.addAll(loaded);
      });

      if (originalImage == null) {
        await openPhoto(loaded.first);
      }
    } catch (_) {
      message('Could not import photos');
    }
  }

  Future<void> openPhoto(Uint8List data) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      var decoded = img.decodeImage(data);

      if (decoded == null) {
        throw Exception('Unsupported image');
      }

      decoded = img.bakeOrientation(decoded);

      // Only the preview is resized.
      // The original stays at full resolution.
      final small = resizePreview(decoded, 850);
      final tiny = resizePreview(decoded, 125);

      final thumbs = <Uint8List?>[];

      thumbs.add(
        Uint8List.fromList(
          img.encodeJpg(tiny, quality: 88),
        ),
      );

      for (int i = 0; i < presets.length; i++) {
        final setting = EditData()..preset = i;

        final result = processPhoto(
          tiny,
          setting,
        );

        thumbs.add(
          Uint8List.fromList(
            img.encodeJpg(result, quality: 82),
          ),
        );
      }

      final effects = <Uint8List?>[];

      for (int i = 0; i < 10; i++) {
        final setting = EditData()
          ..texture = i
          ..textureStrength = .8;

        final result = processPhoto(
          tiny,
          setting,
        );

        effects.add(
          Uint8List.fromList(
            img.encodeJpg(result, quality: 82),
          ),
        );
      }

      final clean = Uint8List.fromList(
        img.encodeJpg(small, quality: 95),
      );

      if (!mounted) return;

      setState(() {
        originalImage = decoded;
        previewSource = small;
        originalPreview = clean;
        previewBytes = clean;

        filterThumbs.setAll(0, thumbs);
        textureThumbs.setAll(0, effects);

        edit = EditData();
        undoHistory.clear();
        redoHistory.clear();

        gallery = false;
        section = 'Filters';
      });
    } catch (_) {
      message('Unable to open image');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void schedulePreview() {
    previewTimer?.cancel();

    previewTimer = Timer(
      const Duration(milliseconds: 180),
      () => updatePreview(),
    );
  }

  Future<void> updatePreview() async {
    if (previewSource == null || busy) return;

    final settings = edit.copy();
    final source = previewSource!;

    setState(() => busy = true);

    try {
      final result = processPhoto(
        source,
        settings,
      );

      final encoded = Uint8List.fromList(
        img.encodeJpg(result, quality: 94),
      );

      if (mounted) {
        setState(() {
          previewBytes = encoded;
        });
      }
    } catch (_) {
      message('Preview failed');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void change(VoidCallback action) {
    if (busy) return;

    saveHistory();
    setState(action);
    schedulePreview();
  }

  void undo() {
    if (busy || undoHistory.isEmpty) return;

    redoHistory.add(edit.copy());

    setState(() {
      edit = undoHistory.removeLast();
    });

    schedulePreview();
  }

  void redo() {
    if (busy || redoHistory.isEmpty) return;

    undoHistory.add(edit.copy());

    setState(() {
      edit = redoHistory.removeLast();
    });

    schedulePreview();
  }

  Future<void> exportPhoto() async {
    if (originalImage == null || busy) return;

    setState(() => busy = true);

    try {
      // Process the full-resolution original.
      final result = processPhoto(
        originalImage!,
        edit.copy(),
      );

      final Uint8List bytes;

      if (exportPng) {
        bytes = Uint8List.fromList(
          img.encodePng(result),
        );
      } else {
        bytes = Uint8List.fromList(
          img.encodeJpg(result, quality: 100),
        );
      }

      final filename = exportPng
          ? 'LTJ3_EDITOR_ULTRA_HD.png'
          : 'LTJ3_EDITOR_ULTRA_HD.jpg';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: exportPng
                ? 'image/png'
                : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [filename],
      );
    } catch (_) {
      message(
        'Export failed. Try JPEG or a smaller image.',
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget customButton(
    String label,
    bool selected,
    VoidCallback callback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Colors.white
              : Colors.white60,
          backgroundColor: selected
              ? const Color(0xFF3B3B3B)
              : tile,
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 13,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget adjust(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> callback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 93,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: silver,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: limit(value, min, max),
              onChangeStart: (_) {
                sliderStart = edit.copy();
              },
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => callback(v));
                      // Preview refreshes after releasing
                      // the slider to keep editing smooth.
                    },
              onChangeEnd: (_) {
                if (sliderStart != null) {
                  undoHistory.add(sliderStart!);
                  redoHistory.clear();
                  sliderStart = null;
                }

                schedulePreview();
              },
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                color: silver,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget welcomeScreen() {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'LTJ3  /  CREATIVE STUDIO',
                style: TextStyle(
                  color: silver,
                  fontSize: 10,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                size: 28,
                color: Colors.white70,
              ),
              const SizedBox(height: 22),
              const Text(
                'LTJ3',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 5,
                  color: Colors.white,
                ),
              ),
              const Text(
                'E D I T O R',
                style: TextStyle(
                  fontSize: 15,
                  letterSpacing: 5,
                  color: silver,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: 70,
                height: 1,
                color: Colors.white38,
              ),
              const SizedBox(height: 27),
              const Text(
                'MAKE EVERY MOMENT\nEXTRAORDINARY.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  height: 2,
                  color: silver,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 57,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      started = true;
                      gallery = true;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              const Text(
                'CREATE  ·  REFINE  ·  EXPORT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget galleryScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            20, 25, 20, 15,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Studio',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 29,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                onPressed: importPhotos,
                icon: const Icon(
                  Icons.add_circle_outline,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: tile),
        Expanded(
          child: photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 65,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 19),
                      const Text(
                        'YOUR CREATIVE SPACE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 3,
                          color: silver,
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Every great edit starts here.',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 30),
                      FilledButton.icon(
                        onPressed: importPhotos,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                        ),
                        label: const Text('Import Photos'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(3),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        openPhoto(photos[index]);
                      },
                      child: Image.memory(
                        photos[index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget filterPanel() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'LTJ3 SIGNATURE COLLECTION',
          style: TextStyle(
            color: silver,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            itemCount: 21,
            itemBuilder: (context, index) {
              final selected =
                  edit.preset == index - 1;

              return GestureDetector(
                onTap: () => change(() {
                  edit.preset = index - 1;
                }),
                child: Container(
                  width: 98,
                  margin: const EdgeInsets.only(right: 9),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: tile,
                          borderRadius:
                              BorderRadius.circular(7),
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: filterThumbs[index] == null
                            ? const Icon(Icons.image)
                            : Image.memory(
                                filterThumbs[index]!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index == 0
                            ? 'ORIGINAL'
                            : '□ LTJ3 ${index.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? Colors.white
                              : silver,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 13),
        adjust(
          'Intensity',
          edit.strength,
          0,
          1,
          (v) => edit.strength = v,
        ),
      ],
    );
  }

  Widget texturePanel() {
    final indices = textureCategory == 0
        ? [0, 1, 2, 3, 4]
        : textureCategory == 1
            ? [0, 5, 6, 7]
            : [0, 8, 9];

    return Column(
      children: [
        const SizedBox(height: 13),
        const Text(
          'LTJ3 TEXTURE STUDIO',
          style: TextStyle(
            color: silver,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < 3; i++)
                customButton(
                  [
                    'NOISE & DUST',
                    'LIGHT LEAK',
                    'BOKEH',
                  ][i],
                  textureCategory == i,
                  () => setState(() {
                    textureCategory = i;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
            ),
            children: [
              for (final i in indices)
                GestureDetector(
                  onTap: () => change(() {
                    edit.texture = i;
                  }),
                  child: Container(
                    width: 90,
                    margin:
                        const EdgeInsets.only(right: 9),
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 82,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: edit.texture == i
                                  ? Colors.white
                                  : tile,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: textureThumbs[i] == null
                              ? const Icon(Icons.texture)
                              : Image.memory(
                                  textureThumbs[i]!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i == 0
                              ? 'NONE'
                              : 'FX ${i.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: silver,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (edit.texture != 0)
          adjust(
            'Texture',
            edit.textureStrength,
            0,
            1,
            (v) => edit.textureStrength = v,
          ),
      ],
    );
  }

  Widget toolsPanel() {
    switch (section) {
      case 'Filters':
        return filterPanel();

      case 'Light':
        return Column(
          children: [
            adjust('Exposure', edit.exposure, -.7, .7,
                (v) => edit.exposure = v),
            adjust('Contrast', edit.contrast, -.5, .5,
                (v) => edit.contrast = v),
            adjust('Highlights', edit.highlights, -1, 1,
                (v) => edit.highlights = v),
            adjust('Shadows', edit.shadows, -1, 1,
                (v) => edit.shadows = v),
          ],
        );

      case 'Color':
        return Column(
          children: [
            adjust('Temperature', edit.temperature, -.3, .3,
                (v) => edit.temperature = v),
            adjust('Saturation', edit.saturation, -1, 1,
                (v) => edit.saturation = v),
            adjust('Fade', edit.fade, 0, .35,
                (v) => edit.fade = v),
          ],
        );

      case 'Details':
        return Column(
          children: [
            adjust('Sharpen', edit.sharpen, 0, 1,
                (v) => edit.sharpen = v),
            adjust('Grain', edit.grain, 0, 1,
                (v) => edit.grain = v),
            adjust('Vignette', edit.vignette, -1, 1,
                (v) => edit.vignette = v),
          ],
        );

      case 'Texture':
        return texturePanel();

      case 'Crop':
        return Column(
          children: [
            const SizedBox(height: 15),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ratio in [
                    'Original',
                    '1:1',
                    '4:5',
                    '3:4',
                    '9:16',
                    '16:9',
                  ])
                    customButton(
                      ratio,
                      edit.ratio == ratio,
                      () => change(() {
                        edit.ratio = ratio;
                      }),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => change(() {
                    edit.rotation =
                        (edit.rotation + 3) % 4;
                  }),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton(
                  onPressed: () => change(() {
                    edit.rotation =
                        (edit.rotation + 1) % 4;
                  }),
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  onPressed: () => change(() {
                    edit.flip = !edit.flip;
                  }),
                  icon: const Icon(Icons.flip),
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget editorScreen() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (_) {
              setState(() => compare = true);
            },
            onLongPressEnd: (_) {
              setState(() => compare = false);
            },
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if ((compare
                          ? originalPreview
                          : previewBytes) !=
                      null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        (compare
                            ? originalPreview
                            : previewBytes)!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (compare)
                    const Positioned(
                      bottom: 18,
                      child: Text(
                        'ORIGINAL',
                        style: TextStyle(
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  if (busy)
                    const Positioned(
                      top: 14,
                      right: 14,
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
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  children: [
                    for (final name in [
                      'Filters',
                      'Light',
                      'Color',
                      'Details',
                      'Texture',
                      'Crop',
                    ])
                      customButton(
                        name,
                        section == name,
                        () => setState(() {
                          section = name;
                        }),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 250,
                child: SingleChildScrollView(
                  child: toolsPanel(),
                ),
              ),
              const Divider(
                height: 1,
                color: tile,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => change(() {
                                edit = EditData();
                              }),
                      icon: const Icon(
                        Icons.restart_alt,
                        size: 19,
                      ),
                      label: const Text('Reset'),
                    ),
                    const Text(
                      'HOLD TO COMPARE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: silver,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : showExportOptions,
                      icon: const Icon(
                        Icons.ios_share,
                        size: 18,
                      ),
                      label: const Text('Export'),
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

  void showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LTJ3 ULTRA HD EXPORT',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Full original resolution',
                  style: TextStyle(color: silver),
                ),
                const SizedBox(height: 20),
                ListTile(
                  title: const Text('JPEG MAX QUALITY'),
                  subtitle: const Text(
                    'Quality 100 · Smaller than PNG',
                  ),
                  leading: const Icon(Icons.image_outlined),
                  onTap: () {
                    exportPng = false;
                    Navigator.pop(sheetContext);
                    exportPhoto();
                  },
                ),
                const Divider(color: tile),
                ListTile(
                  title: const Text('PNG LOSSLESS'),
                  subtitle: const Text(
                    'Lossless compression · Larger file',
                  ),
                  leading:
                      const Icon(Icons.high_quality_outlined),
                  onTap: () {
                    exportPng = true;
                    Navigator.pop(sheetContext);
                    exportPhoto();
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Large images may require more memory '
                  'and processing time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: silver,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!started) {
      return welcomeScreen();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w400,
            letterSpacing: 3,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            setState(() => gallery = true);
          },
          icon: Icon(
            gallery
                ? Icons.grid_view_rounded
                : Icons.arrow_back_ios_new,
          ),
        ),
        actions: [
          if (!gallery)
            IconButton(
              onPressed:
                  busy || undoHistory.isEmpty ? null : undo,
              icon: const Icon(Icons.undo),
            ),
          if (!gallery)
            IconButton(
              onPressed:
                  busy || redoHistory.isEmpty ? null : redo,
              icon: const Icon(Icons.redo),
            ),
          if (!gallery)
            IconButton(
              onPressed:
                  busy ? null : showExportOptions,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: gallery
          ? galleryScreen()
          : editorScreen(),
    );
  }
}
