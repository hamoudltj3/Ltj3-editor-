
import 'dart:convert';
import 'dart:html' as web;
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

const black = Color(0xFF080808);
const panel = Color(0xFF191919);
const tile = Color(0xFF303030);
const silver = Color(0xFFC8C8C8);

double bound(num v, double low, double high) =>
    v.clamp(low, high).toDouble();

class LTJ3Preset {
  final double exposure;
  final double contrast;
  final double saturation;
  final double warmth;
  final double fade;

  const LTJ3Preset(
    this.exposure,
    this.contrast,
    this.saturation,
    this.warmth,
    this.fade,
  );
}

const presets = <LTJ3Preset>[
  LTJ3Preset(.09, .16, .22, .06, 0),
  LTJ3Preset(-.13, .30, -.20, -.10, 0),
  LTJ3Preset(.15, .13, .36, .14, 0),
  LTJ3Preset(.04, -.14, -.24, -.08, .15),
  LTJ3Preset(-.18, .34, -.12, -.08, 0),
  LTJ3Preset(.18, -.16, -.20, .18, .14),
  LTJ3Preset(.08, .26, .36, .09, 0),
  LTJ3Preset(-.12, .20, -.36, -.18, .04),
  LTJ3Preset(.03, .30, -1, 0, 0),
  LTJ3Preset(-.15, .29, -.28, .13, .03),
  LTJ3Preset(.13, .24, .22, .12, 0),
  LTJ3Preset(-.09, -.12, -.42, .16, .18),
  LTJ3Preset(-.17, .24, -.35, -.20, .03),
  LTJ3Preset(.16, .18, .17, .22, 0),
  LTJ3Preset(-.22, .36, -.40, -.14, 0),
  LTJ3Preset(.05, .39, -1, 0, 0),
  LTJ3Preset(-.08, .29, .28, -.15, 0),
  LTJ3Preset(.17, -.18, -.34, .06, .18),
  LTJ3Preset(-.14, .24, -.75, -.10, .04),
  LTJ3Preset(-.10, .40, .12, .15, 0),
];

const textureNames = [
  'NONE',
  'FILM GRAIN',
  'SOFT HAZE',
  'GOLDEN LIGHT',
  'BLUE LIGHT',
  'ROSE GLOW',
  'VINTAGE FILM',
  'BOKEH',
];

class PhotoSettings {
  // Explicit default constructor fixes the old
  // unnamed-constructor problem.
  PhotoSettings();

  int preset = -1;
  int texture = 0;

  double intensity = 1;
  double exposure = 0;
  double contrast = 0;
  double saturation = 0;
  double warmth = 0;
  double shadows = 0;
  double highlights = 0;
  double fade = 0;
  double vignette = 0;
  double sharpen = 0;
  double textureAmount = .5;

  PhotoSettings copy() => PhotoSettings()
    ..preset = preset
    ..texture = texture
    ..intensity = intensity
    ..exposure = exposure
    ..contrast = contrast
    ..saturation = saturation
    ..warmth = warmth
    ..shadows = shadows
    ..highlights = highlights
    ..fade = fade
    ..vignette = vignette
    ..sharpen = sharpen
    ..textureAmount = textureAmount;

  Map<String, dynamic> toJson() => {
    'preset': preset,
    'texture': texture,
    'intensity': intensity,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'warmth': warmth,
    'shadows': shadows,
    'highlights': highlights,
    'fade': fade,
    'vignette': vignette,
    'sharpen': sharpen,
    'textureAmount': textureAmount,
  };

  factory PhotoSettings.fromJson(
    Map<String, dynamic> data,
  ) {
    double read(String key, double fallback) {
      final v = data[key];
      return v is num ? v.toDouble() : fallback;
    }

    return PhotoSettings()
      ..preset = read('preset', -1).toInt()
      ..texture = read('texture', 0).toInt()
      ..intensity = read('intensity', 1)
      ..exposure = read('exposure', 0)
      ..contrast = read('contrast', 0)
      ..saturation = read('saturation', 0)
      ..warmth = read('warmth', 0)
      ..shadows = read('shadows', 0)
      ..highlights = read('highlights', 0)
      ..fade = read('fade', 0)
      ..vignette = read('vignette', 0)
      ..sharpen = read('sharpen', 0)
      ..textureAmount = read('textureAmount', .5);
  }
}

double grainAt(int x, int y) {
  final n = math.sin(
    x * 127.1 + y * 311.7,
  ) * 43758.5453;

  return n - n.floorToDouble();
}

double softGlow(
  double x,
  double y,
  double radius,
) {
  return math.exp(
    -(x * x + y * y) /
        (2 * radius * radius),
  );
}

img.Image makePreview(img.Image image, int maxSide) {
  if (math.max(image.width, image.height) <= maxSide) {
    return img.copyResize(
      image,
      width: image.width,
      height: image.height,
    );
  }

  if (image.width > image.height) {
    return img.copyResize(image, width: maxSide);
  }

  return img.copyResize(image, height: maxSide);
}

img.Image editImage(
  img.Image original,
  PhotoSettings settings,
) {
  final preset = settings.preset >= 0 &&
          settings.preset < presets.length
      ? presets[settings.preset]
      : null;

  final exposure = bound(
    settings.exposure +
        (preset?.exposure ?? 0) * settings.intensity,
    -.85,
    .85,
  );

  final contrast = bound(
    1 +
        settings.contrast +
        (preset?.contrast ?? 0) * settings.intensity,
    .4,
    1.8,
  );

  final saturation = bound(
    1 +
        settings.saturation +
        (preset?.saturation ?? 0) * settings.intensity,
    0,
    2,
  );

  final warmth = bound(
    settings.warmth +
        (preset?.warmth ?? 0) * settings.intensity,
    -.45,
    .45,
  );

  final fade = bound(
    settings.fade +
        (preset?.fade ?? 0) * settings.intensity,
    0,
    .5,
  );

  final gain = math.pow(2, exposure).toDouble();

  final result = original.convert(
    format: img.Format.uint8,
    numChannels: 3,
  );

  final width = result.width.toDouble();
  final height = result.height.toDouble();

  for (final pixel in result) {
    final x = pixel.x;
    final y = pixel.y;
    final nx = x / width;
    final ny = y / height;

    double r = pixel.r / 255;
    double g = pixel.g / 255;
    double b = pixel.b / 255;

    final brightness = bound(
      .2126 * r + .7152 * g + .0722 * b,
      0,
      1,
    );

    final shadowWeight =
        (1 - brightness) * (1 - brightness);

    final highlightWeight =
        brightness * brightness;

    final tone =
        settings.shadows * shadowWeight * .24 +
        settings.highlights * highlightWeight * .20;

    r = ((r * gain + tone + warmth * .18 - .5) *
            contrast) +
        .5;

    g = ((g * gain + tone - .5) * contrast) + .5;

    b = ((b * gain + tone - warmth * .18 - .5) *
            contrast) +
        .5;

    final greyValue =
        .2126 * r + .7152 * g + .0722 * b;

    r = greyValue + (r - greyValue) * saturation;
    g = greyValue + (g - greyValue) * saturation;
    b = greyValue + (b - greyValue) * saturation;

    r = r * (1 - fade) + fade * .5;
    g = g * (1 - fade) + fade * .5;
    b = b * (1 - fade) + fade * .5;

    final dx = (nx - .5) * 2;
    final dy = (ny - .5) * 2;

    final distance = bound(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0,
      1,
    );

    final edge =
        1 - settings.vignette * distance * distance * .7;

    r *= edge;
    g *= edge;
    b *= edge;

    final amount = settings.textureAmount;

    if (settings.texture == 1 ||
        settings.texture == 6) {
      final fineGrain =
          (grainAt(x, y) - .5) * amount * .055;

      r += fineGrain;
      g += fineGrain;
      b += fineGrain;
    }

    if (settings.texture == 2 ||
        settings.texture == 6) {
      final haze = softGlow(
            nx - .5,
            ny - .65,
            .65,
          ) *
          amount *
          .16;

      r = r * (1 - haze) + .78 * haze;
      g = g * (1 - haze) + .75 * haze;
      b = b * (1 - haze) + .72 * haze;
    }

    if (settings.texture >= 3 &&
        settings.texture <= 5) {
      final centerX = settings.texture == 3
          ? -.15
          : settings.texture == 4
              ? 1.15
              : .5;

      final centerY =
          settings.texture == 5 ? -.2 : .5;

      final alpha = bound(
        softGlow(
              nx - centerX,
              ny - centerY,
              .53,
            ) *
            amount *
            .42,
        0,
        .4,
      );

      final cr =
          settings.texture == 4 ? .34 : 1.0;

      final cg =
          settings.texture == 4 ? .62 : .56;

      final cb = settings.texture == 4
          ? 1.0
          : settings.texture == 5
              ? .72
              : .2;

      r = r * (1 - alpha) + cr * alpha;
      g = g * (1 - alpha) + cg * alpha;
      b = b * (1 - alpha) + cb * alpha;
    }

    if (settings.texture == 7) {
      double bokeh = 0;

      for (int i = 0; i < 5; i++) {
        final centerX = grainAt(i, 12);
        final centerY = grainAt(i, 29);

        final radius =
            .04 + grainAt(i, 47) * .06;

        bokeh += softGlow(
              nx - centerX,
              ny - centerY,
              radius,
            ) *
            .15;
      }

      final alpha = bound(
        bokeh * amount,
        0,
        .22,
      );

      r = r * (1 - alpha) + alpha;
      g = g * (1 - alpha) + alpha * .85;
      b = b * (1 - alpha) + alpha * .7;
    }

    pixel.r = (bound(r, 0, 1) * 255).round();
    pixel.g = (bound(g, 0, 1) * 255).round();
    pixel.b = (bound(b, 0, 1) * 255).round();
  }

  if (settings.sharpen > .01) {
    final blur = img.gaussianBlur(
      result,
      radius: 1,
    );

    final strength = settings.sharpen * .6;

    for (final p in result) {
      final q = blur.getPixel(p.x, p.y);

      p.r = bound(
        p.r + (p.r - q.r) * strength,
        0,
        255,
      ).round();

      p.g = bound(
        p.g + (p.g - q.g) * strength,
        0,
        255,
      ).round();

      p.b = bound(
        p.b + (p.b - q.b) * strength,
        0,
        255,
      ).round();
    }
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: panel,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.white,
          inactiveTrackColor: tile,
          thumbColor: Colors.white,
          trackHeight: 3,
        ),
      ),
      home: const LTJ3Studio(),
    );
  }
}

class LTJ3Studio extends StatefulWidget {
  const LTJ3Studio({super.key});

  @override
  State<LTJ3Studio> createState() => _LTJ3StudioState();
}

class _LTJ3StudioState extends State<LTJ3Studio> {
  final ImagePicker picker = ImagePicker();

  final Map<String, PhotoSettings> savedFilters = {};
  final List<Uint8List> library = [];

  PhotoSettings settings = PhotoSettings();

  img.Image? original;
  img.Image? previewSource;

  Uint8List? beforeImage;
  Uint8List? afterImage;

  List<Uint8List> filterThumbnails = [];

  bool started = false;
  bool editing = false;
  bool busy = false;
  bool comparing = false;

  String selectedTab = 'Filters';

  @override
  void initState() {
    super.initState();
    loadSavedFilters();
  }

  void showNotice(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void loadSavedFilters() {
    try {
      final stored =
          web.window.localStorage['ltj3_v8_filters'];

      if (stored == null) return;

      final parsed = jsonDecode(stored) as Map;

      for (final item in parsed.entries) {
        savedFilters[item.key.toString()] =
            PhotoSettings.fromJson(
          Map<String, dynamic>.from(item.value as Map),
        );
      }
    } catch (_) {
      savedFilters.clear();
    }
  }

  void persistFilters() {
    try {
      web.window.localStorage['ltj3_v8_filters'] =
          jsonEncode(
        savedFilters.map(
          (key, value) =>
              MapEntry(key, value.toJson()),
        ),
      );
    } catch (_) {
      showNotice('Could not save custom filters');
    }
  }

  Future<void> importPhoto() async {
    if (busy) return;

    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        library.add(bytes);
      });

      await openPhoto(bytes);
    } catch (_) {
      showNotice('Unable to import photo');
    }
  }

  Future<void> openPhoto(Uint8List bytes) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      var decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unsupported image format');
      }

      decoded = img.bakeOrientation(decoded);

      final preview = makePreview(decoded, 1200);
      final thumbnail = makePreview(decoded, 260);

      final images = <Uint8List>[];

      images.add(
        Uint8List.fromList(
          img.encodeJpg(thumbnail, quality: 95),
        ),
      );

      for (int i = 0; i < presets.length; i++) {
        final presetSettings = PhotoSettings()
          ..preset = i;

        final result = editImage(
          thumbnail,
          presetSettings,
        );

        images.add(
          Uint8List.fromList(
            img.encodeJpg(result, quality: 94),
          ),
        );
      }

      final clean = Uint8List.fromList(
        img.encodeJpg(preview, quality: 96),
      );

      if (!mounted) return;

      setState(() {
        original = decoded;
        previewSource = preview;
        beforeImage = clean;
        afterImage = clean;
        filterThumbnails = images;

        settings = PhotoSettings();
        editing = true;
        selectedTab = 'Filters';
      });
    } catch (_) {
      showNotice('Could not open photo');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> updatePreview() async {
    if (previewSource == null || busy) return;

    setState(() => busy = true);

    try {
      final result = editImage(
        previewSource!,
        settings.copy(),
      );

      final output = Uint8List.fromList(
        img.encodeJpg(result, quality: 96),
      );

      if (!mounted) return;

      setState(() {
        afterImage = output;
      });
    } catch (_) {
      showNotice('Preview failed');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void choosePreset(int index) {
    if (busy) return;

    setState(() {
      settings.preset = index;
    });

    updatePreview();
  }

  Future<void> saveCustomFilter() async {
    if (original == null) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: panel,
          title: const Text('CREATE YOUR FILTER'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 32,
            decoration: const InputDecoration(
              labelText: 'Filter name',
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Save Filter'),
            ),
          ],
        );
      },
    );

    // Dialog is closed; settings are copied below.
    if (!mounted) return;

    if (name == null || name.isEmpty) return;

    setState(() {
      savedFilters[name] = settings.copy();
      selectedTab = 'My Filters';
    });

    persistFilters();
    showNotice('Filter saved: $name');
  }

  Future<void> exportPhoto(bool png) async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      // Use the original full-resolution image.
      final result = editImage(
        original!,
        settings.copy(),
      );

      final bytes = Uint8List.fromList(
        png
            ? img.encodePng(result)
            : img.encodeJpg(result, quality: 100),
      );

      final filename = png
          ? 'LTJ3_EDITOR_ULTRA_HD.png'
          : 'LTJ3_EDITOR_ULTRA_HD.jpg';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: png
                ? 'image/png'
                : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [filename],
      );
    } catch (_) {
      showNotice('Export failed. Try JPEG.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void showExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('LTJ3 ULTRA HD EXPORT'),
                subtitle: Text(
                  'Export from original resolution',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('JPEG MAX QUALITY'),
                subtitle: const Text('Quality 100'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  exportPhoto(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.high_quality),
                title: const Text('PNG LOSSLESS'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  exportPhoto(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget tabButton(String name) {
    final active = selectedTab == name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {
          setState(() => selectedTab = name);
        },
        style: TextButton.styleFrom(
          backgroundColor: active ? tile : panel,
          foregroundColor:
              active ? Colors.white : silver,
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 13,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(name),
      ),
    );
  }

  Widget adjustment(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: silver,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: bound(value, min, max),
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => onChange(v));
                    },
              onChangeEnd: (_) {
                updatePreview();
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                color: silver,
                fontSize: 10,
              ),
            ),
          ),
        ],
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
            fontSize: 11,
            letterSpacing: 2,
            color: silver,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 132,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            itemCount: filterThumbnails.length,
            itemBuilder: (context, index) {
              final selected =
                  settings.preset == index - 1;

              return GestureDetector(
                onTap: () => choosePreset(index - 1),
                child: Container(
                  width: 104,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        height: 100,
                        width: 100,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : tile,
                            width: 2,
                          ),
                          borderRadius:
                              BorderRadius.circular(7),
                        ),
                        child: Image.memory(
                          filterThumbnails[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index == 0
                            ? 'ORIGINAL'
                            : '□ LTJ3 ${index.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: silver,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        adjustment(
          'Intensity',
          settings.intensity,
          0,
          1.5,
          (v) => settings.intensity = v,
        ),
      ],
    );
  }

  Widget texturePanel() {
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
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: textureNames.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(textureNames[i]),
                  selected: settings.texture == i,
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() {
                            settings.texture = i;
                          });
                          updatePreview();
                        },
                ),
              );
            },
          ),
        ),
        adjustment(
          'Texture',
          settings.textureAmount,
          0,
          1,
          (v) => settings.textureAmount = v,
        ),
      ],
    );
  }

  Widget customFiltersPanel() {
    return Column(
      children: [
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: saveCustomFilter,
          icon: const Icon(Icons.bookmark_add),
          label: const Text('CREATE YOUR FILTER'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        if (savedFilters.isEmpty)
          const Text(
            'Your custom filters will appear here.',
            style: TextStyle(color: silver),
          ),
        for (final name in savedFilters.keys.toList())
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(name),
            subtitle: const Text('CUSTOM LTJ3 LOOK'),
            onTap: () {
              if (busy) return;

              setState(() {
                settings = savedFilters[name]!.copy();
              });

              updatePreview();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  savedFilters.remove(name);
                });

                persistFilters();
              },
            ),
          ),
      ],
    );
  }

  Widget controls() {
    switch (selectedTab) {
      case 'Filters':
        return filtersPanel();

      case 'My Filters':
        return customFiltersPanel();

      case 'Texture':
        return texturePanel();

      case 'Light':
        return Column(
          children: [
            adjustment(
              'Exposure',
              settings.exposure,
              -.85,
              .85,
              (v) => settings.exposure = v,
            ),
            adjustment(
              'Contrast',
              settings.contrast,
              -.5,
              .5,
              (v) => settings.contrast = v,
            ),
            adjustment(
              'Highlights',
              settings.highlights,
              -1,
              1,
              (v) => settings.highlights = v,
            ),
            adjustment(
              'Shadows',
              settings.shadows,
              -1,
              1,
              (v) => settings.shadows = v,
            ),
          ],
        );

      case 'Color':
        return Column(
          children: [
            adjustment(
              'Saturation',
              settings.saturation,
              -1,
              1,
              (v) => settings.saturation = v,
            ),
            adjustment(
              'Warmth',
              settings.warmth,
              -.45,
              .45,
              (v) => settings.warmth = v,
            ),
            adjustment(
              'Fade',
              settings.fade,
              0,
              .5,
              (v) => settings.fade = v,
            ),
          ],
        );

      case 'Details':
        return Column(
          children: [
            adjustment(
              'Sharpen',
              settings.sharpen,
              0,
              1,
              (v) => settings.sharpen = v,
            ),
            adjustment(
              'Vignette',
              settings.vignette,
              -1,
              1,
              (v) => settings.vignette = v,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget welcomeScreen() {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
          ),
          child: Column(
            children: [
              const SizedBox(height: 45),
              const Text(
                'LTJ3 / CREATIVE STUDIO',
                style: TextStyle(
                  color: silver,
                  letterSpacing: 4,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                color: silver,
                size: 30,
              ),
              const SizedBox(height: 20),
              const Text(
                'LTJ3',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 78,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
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
              const SizedBox(height: 30),
              Container(
                width: 70,
                height: 1,
                color: Colors.white38,
              ),
              const SizedBox(height: 28),
              const Text(
                'CREATE YOUR OWN VISION.',
                style: TextStyle(
                  color: silver,
                  letterSpacing: 3,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      started = true;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Get Started  →',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'CREATE · REFINE · EXPORT',
                style: TextStyle(
                  fontSize: 11,
                  color: silver,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 35),
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Studio',
                  style: TextStyle(
                    fontSize: 29,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: importPhoto,
                icon: const Icon(Icons.add),
                label: const Text('Import'),
              ),
            ],
          ),
        ),
        Expanded(
          child: library.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: importPhoto,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                    ),
                    label: const Text('Import Photos'),
                  ),
                )
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  itemCount: library.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => openPhoto(library[i]),
                      child: Image.memory(
                        library[i],
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
                  if ((comparing
                          ? beforeImage
                          : afterImage) !=
                      null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        (comparing
                            ? beforeImage
                            : afterImage)!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (busy)
                    const Positioned(
                      top: 12,
                      right: 12,
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
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final name in [
                      'Filters',
                      'My Filters',
                      'Light',
                      'Color',
                      'Details',
                      'Texture',
                    ])
                      tabButton(name),
                  ],
                ),
              ),
              SizedBox(
                height: 252,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: controls(),
                ),
              ),
              const Divider(color: tile, height: 1),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              settings = PhotoSettings();
                            });
                            updatePreview();
                          },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                  const Text(
                    'HOLD TO COMPARE',
                    style: TextStyle(
                      fontSize: 10,
                      color: silver,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : showExportMenu,
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
    if (!started) {
      return welcomeScreen();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: black,
        centerTitle: true,
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 3,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            setState(() {
              editing = false;
            });
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          if (editing)
            IconButton(
              onPressed: busy ? null : showExportMenu,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: editing
          ? editorScreen()
          : galleryScreen(),
    );
  }
}
