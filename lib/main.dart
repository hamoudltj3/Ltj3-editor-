
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

// LTJ3 EDITOR V9
// Flutter Web photo editing studio.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LTJ3App());
}

const bg = Color(0xFF090B0C);
const panel = Color(0xFF181C1E);
const cardColor = Color(0xFF252B2D);
const accent = Color(0xFF69D6C5);
const silver = Color(0xFFCED3D3);
const muted = Color(0xFF8D999A);

double clampValue(num value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

class Look {
  final double light;
  final double contrast;
  final double saturation;
  final double warmth;
  final double fade;

  const Look(
    this.light,
    this.contrast,
    this.saturation,
    this.warmth,
    this.fade,
  );
}

const looks = <Look>[
  Look(.08, .15, .22, .07, 0),
  Look(-.13, .27, -.24, -.12, .01),
  Look(.12, .11, .31, .13, 0),
  Look(.05, -.13, -.23, -.09, .13),
  Look(-.17, .31, -.13, -.07, 0),
  Look(.17, -.15, -.17, .17, .12),
  Look(.07, .23, .36, .07, 0),
  Look(-.10, .18, -.35, -.15, .03),
  Look(.02, .28, -1, 0, 0),
  Look(-.13, .27, -.24, .13, .03),
  Look(.13, .20, .21, .10, 0),
  Look(-.08, -.11, -.43, .16, .17),
  Look(-.16, .22, -.36, -.19, .03),
  Look(.15, .16, .19, .20, 0),
  Look(-.20, .33, -.38, -.13, 0),
  Look(.05, .32, -1, 0, 0),
  Look(-.07, .25, .28, -.14, 0),
  Look(.15, -.17, -.30, .05, .16),
  Look(-.12, .21, -.72, -.09, .04),
  Look(-.09, .35, .13, .15, 0),
];

const textureNames = [
  'NONE',
  'FINE GRAIN',
  'FILM HAZE',
  'GOLDEN GLOW',
  'COOL LIGHT',
  'ROSE GLOW',
  'SOFT BOKEH',
];

class EditorValues {
  EditorValues();

  int filter = -1;
  int texture = 0;
  double intensity = 1;
  double exposure = 0;
  double contrast = 0;
  double saturation = 0;
  double temperature = 0;
  double highlights = 0;
  double shadows = 0;
  double sharpen = 0;
  double vignette = 0;
  double texturePower = .6;

  EditorValues copy() => EditorValues()
    ..filter = filter
    ..texture = texture
    ..intensity = intensity
    ..exposure = exposure
    ..contrast = contrast
    ..saturation = saturation
    ..temperature = temperature
    ..highlights = highlights
    ..shadows = shadows
    ..sharpen = sharpen
    ..vignette = vignette
    ..texturePower = texturePower;

  Map<String, dynamic> toJson() => {
    'filter': filter,
    'texture': texture,
    'intensity': intensity,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'highlights': highlights,
    'shadows': shadows,
    'sharpen': sharpen,
    'vignette': vignette,
    'texturePower': texturePower,
  };

  factory EditorValues.fromJson(Map<String, dynamic> data) {
    double read(String key, double fallback) {
      final value = data[key];
      return value is num ? value.toDouble() : fallback;
    }

    return EditorValues()
      ..filter = read('filter', -1).toInt()
      ..texture = read('texture', 0).toInt()
      ..intensity = read('intensity', 1)
      ..exposure = read('exposure', 0)
      ..contrast = read('contrast', 0)
      ..saturation = read('saturation', 0)
      ..temperature = read('temperature', 0)
      ..highlights = read('highlights', 0)
      ..shadows = read('shadows', 0)
      ..sharpen = read('sharpen', 0)
      ..vignette = read('vignette', 0)
      ..texturePower = read('texturePower', .6);
  }
}

double noise(int x, int y, int seed) {
  final n = math.sin(
    x * 12.9898 + y * 78.233 + seed * 19.19,
  ) * 43758.5453;
  return n - n.floorToDouble();
}

double glow(double dx, double dy, double radius) {
  return math.exp(
    -(dx * dx + dy * dy) / (2 * radius * radius),
  );
}

im.Image resizeImage(im.Image image, int size) {
  if (math.max(image.width, image.height) <= size) {
    return im.copyResize(
      image,
      width: image.width,
      height: image.height,
    );
  }

  return image.width >= image.height
      ? im.copyResize(image, width: size)
      : im.copyResize(image, height: size);
}

im.Image applyEdit(im.Image source, EditorValues e) {
  final preset = e.filter >= 0 &&
          e.filter < looks.length
      ? looks[e.filter]
      : null;

  final exposure = clampValue(
    e.exposure + (preset?.light ?? 0) * e.intensity,
    -.75,
    .75,
  );

  final contrast = clampValue(
    1 + e.contrast +
        (preset?.contrast ?? 0) * e.intensity,
    .55,
    1.55,
  );

  final saturation = clampValue(
    1 + e.saturation +
        (preset?.saturation ?? 0) * e.intensity,
    0,
    1.8,
  );

  final warmth = clampValue(
    e.temperature +
        (preset?.warmth ?? 0) * e.intensity,
    -.3,
    .3,
  );

  final fade = clampValue(
    (preset?.fade ?? 0) * e.intensity,
    0,
    .3,
  );

  final gain = math.pow(2, exposure).toDouble();

  final out = source.convert(
    format: im.Format.uint8,
    numChannels: 3,
  );

  final width = out.width.toDouble();
  final height = out.height.toDouble();

  for (final pixel in out) {
    final x = pixel.x;
    final y = pixel.y;
    final nx = x / width;
    final ny = y / height;

    double r = pixel.r / 255;
    double g = pixel.g / 255;
    double b = pixel.b / 255;

    final luminance = clampValue(
      .2126 * r + .7152 * g + .0722 * b,
      0,
      1,
    );

    final shadowWeight =
        (1 - luminance) * (1 - luminance);
    final highlightWeight = luminance * luminance;

    final tone =
        e.shadows * shadowWeight * .21 +
        e.highlights * highlightWeight * .19;

    r = (r * gain + tone + warmth * .17 - .5) *
            contrast +
        .5;
    g = (g * gain + tone - .5) * contrast + .5;
    b = (b * gain + tone - warmth * .17 - .5) *
            contrast +
        .5;

    final gray = .2126 * r + .7152 * g + .0722 * b;

    r = gray + (r - gray) * saturation;
    g = gray + (g - gray) * saturation;
    b = gray + (b - gray) * saturation;

    r = r * (1 - fade) + fade * .5;
    g = g * (1 - fade) + fade * .5;
    b = b * (1 - fade) + fade * .5;

    final dx = (nx - .5) * 2;
    final dy = (ny - .5) * 2;
    final distance = clampValue(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0,
      1,
    );

    final vignette =
        1 - e.vignette * distance * distance * .65;

    r *= vignette;
    g *= vignette;
    b *= vignette;

    final power = e.texturePower;

    if (e.texture == 1) {
      final grain = (noise(x, y, 7) - .5) *
          power *
          .14;
      r += grain;
      g += grain;
      b += grain;
    }

    if (e.texture == 2) {
      final haze =
          glow(nx - .5, ny - .55, .6) * power * .22;
      r = r * (1 - haze) + .82 * haze;
      g = g * (1 - haze) + .79 * haze;
      b = b * (1 - haze) + .76 * haze;
    }

    if (e.texture >= 3 && e.texture <= 5) {
      final cx = e.texture == 3
          ? -.15
          : e.texture == 4
              ? 1.15
              : .45;
      final cy = e.texture == 5 ? -.15 : .5;

      final alpha = clampValue(
        glow(nx - cx, ny - cy, .5) * power * .5,
        0,
        .48,
      );

      final cr = e.texture == 4 ? .3 : 1.0;
      final cg = e.texture == 4 ? .65 : .55;
      final cb = e.texture == 4
          ? 1.0
          : e.texture == 5
              ? .75
              : .2;

      r = r * (1 - alpha) + cr * alpha;
      g = g * (1 - alpha) + cg * alpha;
      b = b * (1 - alpha) + cb * alpha;
    }

    if (e.texture == 6) {
      double bokeh = 0;

      for (int i = 0; i < 7; i++) {
        final bx = noise(i, 2, 17);
        final by = noise(i, 4, 27);
        final radius = .03 + noise(i, 8, 9) * .07;

        bokeh += glow(
          nx - bx,
          ny - by,
          radius,
        ) * .16;
      }

      final alpha =
          clampValue(bokeh * power, 0, .3);

      r = r * (1 - alpha) + alpha;
      g = g * (1 - alpha) + alpha * .88;
      b = b * (1 - alpha) + alpha * .74;
    }

    pixel.r = (clampValue(r, 0, 1) * 255).round();
    pixel.g = (clampValue(g, 0, 1) * 255).round();
    pixel.b = (clampValue(b, 0, 1) * 255).round();
  }

  if (e.sharpen > 0) {
    final blurred = im.gaussianBlur(out, radius: 1);
    final amount = e.sharpen * .55;

    for (final p in out) {
      final q = blurred.getPixel(p.x, p.y);

      p.r = clampValue(
        p.r + (p.r - q.r) * amount,
        0,
        255,
      ).round();

      p.g = clampValue(
        p.g + (p.g - q.g) * amount,
        0,
        255,
      ).round();

      p.b = clampValue(
        p.b + (p.b - q.b) * amount,
        0,
        255,
      ).round();
    }
  }

  return out;
}

class LTJ3App extends StatelessWidget {
  const LTJ3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LTJ3 EDITOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: Color(0xFF061715),
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accent,
          thumbColor: accent,
          inactiveTrackColor: Color(0xFF465254),
          trackHeight: 3,
        ),
      ),
      home: const Studio(),
    );
  }
}

class Studio extends StatefulWidget {
  const Studio({super.key});

  @override
  State<Studio> createState() => _StudioState();
}

class _StudioState extends State<Studio> {
  final picker = ImagePicker();

  final photos = <Uint8List>[];
  final saved = <String, EditorValues>{};

  EditorValues edit = EditorValues();

  im.Image? original;
  im.Image? previewSource;

  Uint8List? before;
  Uint8List? after;

  final thumbnails = <Uint8List>[];
  final customThumbs = <String, Uint8List>{};

  bool started = false;
  bool editing = false;
  bool busy = false;
  bool comparing = false;

  String tab = 'Filters';
  bool pngExport = false;

  @override
  void initState() {
    super.initState();
    loadFilters();
  }

  void notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void loadFilters() {
    try {
      final value =
          html.window.localStorage['ltj3_v9_filters'];

      if (value == null) return;

      final data = jsonDecode(value) as Map;

      for (final entry in data.entries) {
        saved[entry.key.toString()] =
            EditorValues.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    } catch (_) {
      saved.clear();
    }
  }

  void persistFilters() {
    try {
      html.window.localStorage['ltj3_v9_filters'] =
          jsonEncode(
        saved.map(
          (key, value) =>
              MapEntry(key, value.toJson()),
        ),
      );
    } catch (_) {
      notice('Could not save filter');
    }
  }

  Uint8List encodePreview(im.Image image) {
    return Uint8List.fromList(
      im.encodeJpg(image, quality: 95),
    );
  }

  void rebuildCustomThumbnails(im.Image image) {
    customThumbs.clear();

    for (final entry in saved.entries) {
      customThumbs[entry.key] = encodePreview(
        applyEdit(image, entry.value.copy()),
      );
    }
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

      setState(() => photos.addAll(loaded));

      if (original == null) {
        await openPhoto(loaded.first);
      }
    } catch (_) {
      notice('Import failed');
    }
  }

  Future<void> openPhoto(Uint8List bytes) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      var decoded = im.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unsupported photo');
      }

      decoded = im.bakeOrientation(decoded);

      final large = resizeImage(decoded, 1050);
      final tiny = resizeImage(decoded, 220);

      final previews = <Uint8List>[];

      previews.add(encodePreview(tiny));

      for (int i = 0; i < looks.length; i++) {
        final values = EditorValues()..filter = i;

        previews.add(
          encodePreview(applyEdit(tiny, values)),
        );
      }

      rebuildCustomThumbnails(tiny);

      if (!mounted) return;

      setState(() {
        original = decoded;
        previewSource = large;
        before = encodePreview(large);
        after = before;
        thumbnails
          ..clear()
          ..addAll(previews);
        edit = EditorValues();
        editing = true;
        tab = 'Filters';
      });
    } catch (_) {
      notice('Unable to open photo');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (previewSource == null || busy) return;

    setState(() => busy = true);

    try {
      final result = applyEdit(
        previewSource!,
        edit.copy(),
      );

      final data = encodePreview(result);

      if (mounted) {
        setState(() => after = data);
      }
    } catch (_) {
      notice('Preview failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void selectFilter(int index) {
    if (busy) return;

    setState(() => edit.filter = index);
    refresh();
  }

  Future<void> saveCustomFilter() async {
    if (original == null || busy) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('CREATE YOUR FILTER'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Filter Name',
            hintText: 'My Signature',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.isEmpty) {
      return;
    }

    setState(() {
      saved[name] = edit.copy();
    });

    if (previewSource != null) {
      final small = resizeImage(previewSource!, 220);

      customThumbs[name] = encodePreview(
        applyEdit(small, edit.copy()),
      );
    }

    persistFilters();
    notice('Filter saved: $name');
  }

  void useSavedFilter(String name) {
    if (busy) return;

    final values = saved[name];
    if (values == null) return;

    setState(() => edit = values.copy());
    refresh();
  }

  void deleteFilter(String name) {
    setState(() {
      saved.remove(name);
      customThumbs.remove(name);
    });

    persistFilters();
  }

  Future<void> exportPhoto(bool png) async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final image = applyEdit(
        original!,
        edit.copy(),
      );

      final data = Uint8List.fromList(
        png
            ? im.encodePng(image)
            : im.encodeJpg(image, quality: 100),
      );

      final filename = png
          ? 'LTJ3_EDITOR.png'
          : 'LTJ3_EDITOR.jpg';

      await Share.shareXFiles(
        [
          XFile.fromData(
            data,
            name: filename,
            mimeType: png
                ? 'image/png'
                : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [filename],
      );
    } catch (_) {
      notice('Export failed. Try a smaller photo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void exportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('ULTRA HD EXPORT'),
              subtitle: Text('Original resolution'),
            ),
            ListTile(
              title: const Text('JPEG MAX QUALITY'),
              onTap: () {
                Navigator.pop(context);
                exportPhoto(false);
              },
            ),
            ListTile(
              title: const Text('PNG LOSSLESS'),
              onTap: () {
                Navigator.pop(context);
                exportPhoto(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget chip(
    String name,
    bool active,
    VoidCallback tap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          foregroundColor:
              active ? const Color(0xFF061715) : silver,
          backgroundColor:
              active ? accent : cardColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(name),
      ),
    );
  }

  Widget slider(
    String name,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              color: silver,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: clampValue(value, min, max),
            min: min,
            max: max,
            onChanged: busy
                ? null
                : (v) => setState(() => change(v)),
            onChangeEnd: (_) => refresh(),
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 10,
              color: muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget filterTile(
    String name,
    Uint8List? image,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 102,
        child: Column(
          children: [
            Container(
              width: 94,
              height: 90,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? accent : cardColor,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: image == null
                  ? const Icon(Icons.auto_awesome)
                  : Image.memory(
                      image,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: silver,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget filtersPanel() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'LTJ3 SIGNATURE COLLECTION',
          style: TextStyle(
            letterSpacing: 2,
            color: silver,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 125,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            children: [
              GestureDetector(
                onTap: saveCustomFilter,
                child: SizedBox(
                  width: 103,
                  child: Column(
                    children: [
                      Container(
                        height: 90,
                        width: 94,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius:
                              BorderRadius.circular(9),
                          border: Border.all(
                            color: accent,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: accent,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'CREATE FILTER',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final name in saved.keys.toList())
                GestureDetector(
                  onLongPress: () => deleteFilter(name),
                  child: filterTile(
                    name,
                    customThumbs[name],
                    false,
                    () => useSavedFilter(name),
                  ),
                ),
              if (thumbnails.isNotEmpty)
                filterTile(
                  'ORIGINAL',
                  thumbnails[0],
                  edit.filter == -1,
                  () => selectFilter(-1),
                ),
              for (int i = 0; i < looks.length; i++)
                if (thumbnails.length > i + 1)
                  filterTile(
                    'LTJ3 ${(i + 1).toString().padLeft(2, '0')}',
                    thumbnails[i + 1],
                    edit.filter == i,
                    () => selectFilter(i),
                  ),
            ],
          ),
        ),
        slider(
          'Intensity',
          edit.intensity,
          0,
          1.5,
          (v) => edit.intensity = v,
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Hold a saved filter to delete it',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget toolsPanel() {
    switch (tab) {
      case 'Filters':
        return filtersPanel();

      case 'Light':
        return Column(
          children: [
            slider('Exposure', edit.exposure, -.75, .75,
                (v) => edit.exposure = v),
            slider('Contrast', edit.contrast, -.5, .5,
                (v) => edit.contrast = v),
            slider('Highlights', edit.highlights, -1, 1,
                (v) => edit.highlights = v),
            slider('Shadows', edit.shadows, -1, 1,
                (v) => edit.shadows = v),
          ],
        );

      case 'Color':
        return Column(
          children: [
            slider('Saturation', edit.saturation, -1, 1,
                (v) => edit.saturation = v),
            slider('Temperature', edit.temperature, -.3, .3,
                (v) => edit.temperature = v),
          ],
        );

      case 'Details':
        return Column(
          children: [
            slider('Sharpen', edit.sharpen, 0, 1,
                (v) => edit.sharpen = v),
            slider('Vignette', edit.vignette, -1, 1,
                (v) => edit.vignette = v),
          ],
        );

      case 'Texture':
        return Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 57,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0;
                      i < textureNames.length;
                      i++)
                    chip(
                      textureNames[i],
                      edit.texture == i,
                      () {
                        if (busy) return;
                        setState(() => edit.texture = i);
                        refresh();
                      },
                    ),
                ],
              ),
            ),
            slider(
              'Strength',
              edit.texturePower,
              0,
              1,
              (v) => edit.texturePower = v,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget welcome() {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),
          child: Column(
            children: [
              const SizedBox(height: 45),
              const Text(
                'LTJ3 / CREATIVE STUDIO',
                style: TextStyle(
                  letterSpacing: 4,
                  color: silver,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                color: accent,
                size: 32,
              ),
              const SizedBox(height: 18),
              const Text(
                'LTJ3',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Text(
                'E D I T O R',
                style: TextStyle(
                  letterSpacing: 5,
                  color: silver,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: 70,
                height: 1,
                color: accent,
              ),
              const SizedBox(height: 30),
              const Text(
                'CREATE YOUR OWN VISION.',
                style: TextStyle(
                  letterSpacing: 3,
                  color: silver,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () {
                    setState(() => started = true);
                  },
                  child: const Text(
                    'Get Started  →',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }

  Widget gallery() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'YOUR CREATIVE WORKSPACE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Studio.',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('NEW PROJECT'),
                  Icon(Icons.add, color: accent),
                ],
              ),
              const SizedBox(height: 30),
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: silver,
                size: 55,
              ),
              const SizedBox(height: 13),
              const Text(
                'Create Something Beautiful',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your next masterpiece starts here.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: importPhotos,
                  icon: const Icon(Icons.add),
                  label: const Text('Import Photos'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Recent Projects',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (photos.isEmpty)
          Container(
            height: 125,
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No projects yet',
                style: TextStyle(color: muted),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => openPhoto(photos[index]),
                child: Image.memory(
                  photos[index],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: accent),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LTJ3 Signature Collection',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '20 filters + your custom looks',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ],
    );
  }

  Widget editor() {
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
              color: Colors.black,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if ((comparing ? before : after) != null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        (comparing ? before : after)!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
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
                  if (comparing)
                    const Positioned(
                      bottom: 15,
                      child: Text('ORIGINAL'),
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
                height: 57,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(5),
                  children: [
                    for (final name in [
                      'Filters',
                      'Light',
                      'Color',
                      'Details',
                      'Texture',
                    ])
                      chip(
                        name,
                        tab == name,
                        () => setState(() => tab = name),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 215,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: toolsPanel(),
                ),
              ),
              const Divider(height: 1, color: cardColor),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              edit = EditorValues();
                            });
                            refresh();
                          },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                  const Text(
                    'HOLD TO COMPARE',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : exportMenu,
                    icon: const Icon(Icons.ios_share),
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
    if (!started) return welcome();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            letterSpacing: 3,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            setState(() => editing = false);
          },
          icon: Icon(
            editing
                ? Icons.arrow_back_ios_new
                : Icons.grid_view_rounded,
          ),
        ),
        actions: [
          if (editing)
            IconButton(
              onPressed: busy ? null : exportMenu,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: editing ? editor() : gallery(),
    );
  }
}
