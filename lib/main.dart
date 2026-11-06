
 // ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const LTJ3App());

const black = Color(0xFF080808);
const dark = Color(0xFF191919);
const grey = Color(0xFF303030);
const silver = Color(0xFFCCCCCC);

double cap(num n, double a, double b) =>
    n.clamp(a, b).toDouble();

class FilterLook {
  final double light, contrast, color, warmth, fade;
  const FilterLook(
    this.light,
    this.contrast,
    this.color,
    this.warmth,
    this.fade,
  );
}

const looks = <FilterLook>[
  FilterLook(.10, .18, .24, .08, 0),
  FilterLook(-.15, .33, -.25, -.12, 0),
  FilterLook(.16, .14, .38, .12, 0),
  FilterLook(.05, -.15, -.28, -.08, .16),
  FilterLook(-.20, .40, -.15, -.08, 0),
  FilterLook(.20, -.19, -.22, .20, .14),
  FilterLook(.08, .28, .42, .10, 0),
  FilterLook(-.12, .24, -.42, -.20, .04),
  FilterLook(.02, .38, -1, 0, 0),
  FilterLook(-.18, .30, -.28, .15, .03),
  FilterLook(.15, .29, .25, .12, 0),
  FilterLook(-.10, -.13, -.50, .19, .20),
  FilterLook(-.20, .28, -.40, -.22, .03),
  FilterLook(.18, .19, .18, .24, 0),
  FilterLook(-.25, .42, -.45, -.15, 0),
  FilterLook(.08, .45, -1, 0, 0),
  FilterLook(-.09, .33, .30, -.17, 0),
  FilterLook(.19, -.20, -.40, .06, .20),
  FilterLook(-.17, .28, -.80, -.12, .04),
  FilterLook(-.12, .46, .14, .17, 0),
];

const textures = [
  'NONE',
  'FINE GRAIN',
  'SOFT HAZE',
  'GOLDEN GLOW',
  'COOL LIGHT',
  'ROSE LIGHT',
  'FILM LOOK',
  'SOFT BOKEH',
];

class Settings {
  int filter = -1;
  int texture = 0;

  double strength = 1;
  double exposure = 0;
  double contrast = 0;
  double saturation = 0;
  double temperature = 0;
  double shadows = 0;
  double highlights = 0;
  double fade = 0;
  double vignette = 0;
  double sharpen = 0;
  double textureAmount = .5;

  Settings copy() => Settings()
    ..filter = filter
    ..texture = texture
    ..strength = strength
    ..exposure = exposure
    ..contrast = contrast
    ..saturation = saturation
    ..temperature = temperature
    ..shadows = shadows
    ..highlights = highlights
    ..fade = fade
    ..vignette = vignette
    ..sharpen = sharpen
    ..textureAmount = textureAmount;

  Map<String, dynamic> toJson() => {
    'filter': filter,
    'texture': texture,
    'strength': strength,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'shadows': shadows,
    'highlights': highlights,
    'fade': fade,
    'vignette': vignette,
    'sharpen': sharpen,
    'textureAmount': textureAmount,
  };

  factory Settings.fromJson(Map<String, dynamic> j) {
    double read(String k, double fallback) {
      final v = j[k];
      return v is num ? v.toDouble() : fallback;
    }

    return Settings()
      ..filter = read('filter', -1).toInt()
      ..texture = read('texture', 0).toInt()
      ..strength = read('strength', 1)
      ..exposure = read('exposure', 0)
      ..contrast = read('contrast', 0)
      ..saturation = read('saturation', 0)
      ..temperature = read('temperature', 0)
      ..shadows = read('shadows', 0)
      ..highlights = read('highlights', 0)
      ..fade = read('fade', 0)
      ..vignette = read('vignette', 0)
      ..sharpen = read('sharpen', 0)
      ..textureAmount = read('textureAmount', .5);
  }
}

double hash(int x, int y) {
  final v = math.sin(x * 12.9898 + y * 78.233) *
      43758.5453;
  return v - v.floorToDouble();
}

double glow(double x, double y, double r) =>
    math.exp(-(x * x + y * y) / (2 * r * r));

im.Image resizeImage(im.Image source, int maxSide) {
  if (math.max(source.width, source.height) <= maxSide) {
    return im.copyResize(
      source,
      width: source.width,
      height: source.height,
    );
  }

  return source.width >= source.height
      ? im.copyResize(source, width: maxSide)
      : im.copyResize(source, height: maxSide);
}

im.Image render(im.Image source, Settings s) {
  final f = s.filter >= 0 && s.filter < looks.length
      ? looks[s.filter]
      : null;

  final exposure = cap(
    s.exposure + (f?.light ?? 0) * s.strength,
    -.8, .8,
  );

  final contrast = cap(
    1 + s.contrast +
        (f?.contrast ?? 0) * s.strength,
    .4, 1.8,
  );

  final saturation = cap(
    1 + s.saturation +
        (f?.color ?? 0) * s.strength,
    0, 2,
  );

  final warmth = cap(
    s.temperature +
        (f?.warmth ?? 0) * s.strength,
    -.5, .5,
  );

  final fade = cap(
    s.fade + (f?.fade ?? 0) * s.strength,
    0, .5,
  );

  final gain = math.pow(2, exposure).toDouble();

  final out = source.convert(
    format: im.Format.uint8,
    numChannels: 3,
  );

  final w = out.width.toDouble();
  final h = out.height.toDouble();

  for (final pixel in out) {
    final x = pixel.x;
    final y = pixel.y;
    final nx = x / w;
    final ny = y / h;

    double r = pixel.r / 255;
    double g = pixel.g / 255;
    double b = pixel.b / 255;

    final luma = cap(
      .2126 * r + .7152 * g + .0722 * b,
      0, 1,
    );

    final tone =
        s.shadows * math.pow(1 - luma, 2) * .22 +
        s.highlights * math.pow(luma, 2) * .20;

    r = ((r * gain + tone + warmth * .18 - .5) *
            contrast) + .5;
    g = ((g * gain + tone - .5) * contrast) + .5;
    b = ((b * gain + tone - warmth * .18 - .5) *
            contrast) + .5;

    final gray = .2126 * r + .7152 * g + .0722 * b;

    r = gray + (r - gray) * saturation;
    g = gray + (g - gray) * saturation;
    b = gray + (b - gray) * saturation;

    r = r * (1 - fade) + fade * .5;
    g = g * (1 - fade) + fade * .5;
    b = b * (1 - fade) + fade * .5;

    final dx = (nx - .5) * 2;
    final dy = (ny - .5) * 2;
    final dist = cap(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0, 1,
    );

    final edge = 1 - s.vignette * dist * dist * .7;
    r *= edge;
    g *= edge;
    b *= edge;

    final a = s.textureAmount;

    if (s.texture == 1 || s.texture == 6) {
      final grain = (hash(x, y) - .5) * a * .05;
      r += grain;
      g += grain;
      b += grain;
    }

    if (s.texture == 2 || s.texture == 6) {
      final haze = glow(
        nx - .5,
        ny - .7,
        .65,
      ) * a * .14;

      r = r * (1 - haze) + .75 * haze;
      g = g * (1 - haze) + .73 * haze;
      b = b * (1 - haze) + .72 * haze;
    }

    if (s.texture >= 3 && s.texture <= 5) {
      final cx = s.texture == 3
          ? -.2
          : s.texture == 4 ? 1.2 : .5;

      final cy = s.texture == 5 ? -.2 : .55;

      final light = cap(
        glow(nx - cx, ny - cy, .55) * a * .4,
        0, .35,
      );

      final cr = s.texture == 4 ? .35 : 1.0;
      final cg = s.texture == 4 ? .60 : .55;
      final cb = s.texture == 4
          ? 1.0 : s.texture == 5 ? .7 : .20;

      r = r * (1 - light) + cr * light;
      g = g * (1 - light) + cg * light;
      b = b * (1 - light) + cb * light;
    }

    if (s.texture == 7) {
      double light = 0;

      for (int i = 0; i < 5; i++) {
        final cx = hash(i, 12);
        final cy = hash(i, 29);
        final radius = .04 + hash(i, 47) * .06;

        light += glow(
          nx - cx,
          ny - cy,
          radius,
        ) * .12;
      }

      light = cap(light * a, 0, .18);

      r = r * (1 - light) + light;
      g = g * (1 - light) + light * .86;
      b = b * (1 - light) + light * .70;
    }

    pixel.r = (cap(r, 0, 1) * 255).round();
    pixel.g = (cap(g, 0, 1) * 255).round();
    pixel.b = (cap(b, 0, 1) * 255).round();
  }

  if (s.sharpen > 0) {
    final blurred = im.gaussianBlur(out, radius: 1);
    final amount = s.sharpen * .6;

    for (final pixel in out) {
      final q = blurred.getPixel(pixel.x, pixel.y);

      pixel.r = cap(
        pixel.r + (pixel.r - q.r) * amount,
        0, 255,
      ).round();

      pixel.g = cap(
        pixel.g + (pixel.g - q.g) * amount,
        0, 255,
      ).round();

      pixel.b = cap(
        pixel.b + (pixel.b - q.b) * amount,
        0, 255,
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
        scaffoldBackgroundColor: black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: dark,
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

  final saved = <String, Settings>{};
  final photos = <Uint8List>[];

  Settings settings = Settings();

  im.Image? original;
  im.Image? previewSource;

  Uint8List? preview;
  Uint8List? before;

  List<Uint8List> thumbnails = [];

  bool started = false;
  bool editing = false;
  bool busy = false;
  bool comparing = false;

  String section = 'Filters';

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  void loadSaved() {
    try {
      final raw =
          html.window.localStorage['ltj3_filters_v7'];

      if (raw == null) return;

      final data = jsonDecode(raw) as Map;

      for (final entry in data.entries) {
        saved[entry.key.toString()] =
            Settings.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    } catch (_) {
      saved.clear();
    }
  }

  void persist() {
    try {
      html.window.localStorage['ltj3_filters_v7'] =
          jsonEncode(
        saved.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
      );
    } catch (_) {
      showMessage('Unable to save filters');
    }
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> importPhoto() async {
    if (busy) return;

    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() => photos.add(bytes));

      await openPhoto(bytes);
    } catch (_) {
      showMessage('Import failed');
    }
  }

  Future<void> openPhoto(Uint8List bytes) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      var decoded = im.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Unsupported image');
      }

      decoded = im.bakeOrientation(decoded);

      final small = resizeImage(decoded, 1100);
      final thumb = resizeImage(decoded, 240);

      final results = <Uint8List>[];

      results.add(
        Uint8List.fromList(
          im.encodeJpg(thumb, quality: 95),
        ),
      );

      for (int i = 0; i < 20; i++) {
        final s = Settings()..filter = i;

        results.add(
          Uint8List.fromList(
            im.encodeJpg(
              render(thumb, s),
              quality: 94,
            ),
          ),
        );
      }

      final clean = Uint8List.fromList(
        im.encodeJpg(small, quality: 96),
      );

      if (!mounted) return;

      setState(() {
        original = decoded;
        previewSource = small;
        before = clean;
        preview = clean;
        thumbnails = results;
        settings = Settings();
        editing = true;
        section = 'Filters';
      });
    } catch (_) {
      showMessage('Could not open photo');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refreshPreview() async {
    if (previewSource == null || busy) return;

    setState(() => busy = true);

    try {
      final image = render(
        previewSource!,
        settings.copy(),
      );

      final bytes = Uint8List.fromList(
        im.encodeJpg(image, quality: 96),
      );

      if (!mounted) return;

      setState(() => preview = bytes);
    } catch (_) {
      showMessage('Preview failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void selectFilter(int index) {
    if (busy) return;

    setState(() {
      settings.filter = index;
    });

    refreshPreview();
  }

  Future<void> saveFilter() async {
    if (original == null) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CREATE YOUR FILTER'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(
            hintText: 'My Signature',
            labelText: 'Filter Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    setState(() {
      saved[name] = settings.copy();
      section = 'My Filters';
    });

    persist();
    showMessage('Filter saved: $name');
  }

  Future<void> exportPhoto(bool png) async {
    if (original == null || busy) return;

    setState(() => busy = true);

    try {
      final output = render(
        original!,
        settings.copy(),
      );

      final bytes = Uint8List.fromList(
        png
            ? im.encodePng(output)
            : im.encodeJpg(output, quality: 100),
      );

      final filename =
          png ? 'LTJ3_EDIT.png' : 'LTJ3_EDIT.jpg';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType:
                png ? 'image/png' : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [filename],
      );
    } catch (_) {
      showMessage('Export failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void exportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('LTJ3 ULTRA HD EXPORT'),
            ),
            ListTile(
              title: const Text('JPEG QUALITY 100'),
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

  Widget pill(
    String name,
    bool selected,
    VoidCallback tap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          backgroundColor:
              selected ? grey : dark,
          foregroundColor:
              selected ? Colors.white : silver,
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(name),
      ),
    );
  }

  Widget adjust(
    String name,
    double value,
    double min,
    double max,
    ValueChanged<double> callback,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            name,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: cap(value, min, max),
            min: min,
            max: max,
            activeColor: Colors.white,
            onChanged: busy
                ? null
                : (v) => setState(() => callback(v)),
            onChangeEnd: (_) => refreshPreview(),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget filterList() {
    return Column(
      children: [
        const Text(
          'LTJ3 SIGNATURE COLLECTION',
          style: TextStyle(
            letterSpacing: 2,
            color: silver,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 127,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: thumbnails.length,
            itemBuilder: (context, i) {
              final selected =
                  settings.filter == i - 1;

              return GestureDetector(
                onTap: () => selectFilter(i - 1),
                child: Container(
                  width: 100,
                  margin:
                      const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        height: 99,
                        width: 99,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : grey,
                            width: 2,
                          ),
                          borderRadius:
                              BorderRadius.circular(7),
                        ),
                        child: Image.memory(
                          thumbnails[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        i == 0
                            ? 'ORIGINAL'
                            : '□ LTJ3 ${i.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        adjust(
          'Intensity',
          settings.strength,
          0, 1.5,
          (v) => settings.strength = v,
        ),
      ],
    );
  }

  Widget customList() {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: saveFilter,
          icon: const Icon(Icons.bookmark_add),
          label: const Text('CREATE YOUR FILTER'),
        ),
        for (final name in saved.keys.toList())
          ListTile(
            title: Text(name),
            leading: const Icon(Icons.auto_awesome),
            onTap: () {
              if (busy) return;

              setState(() {
                settings = saved[name]!.copy();
              });

              refreshPreview();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => saved.remove(name));
                persist();
              },
            ),
          ),
      ],
    );
  }

  Widget textureList() {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: textures.length,
            itemBuilder: (context, i) => pill(
              textures[i],
              settings.texture == i,
              () {
                if (busy) return;

                setState(() => settings.texture = i);
                refreshPreview();
              },
            ),
          ),
        ),
        adjust(
          'Texture',
          settings.textureAmount,
          0, 1,
          (v) => settings.textureAmount = v,
        ),
      ],
    );
  }

  Widget controls() {
    switch (section) {
      case 'Filters':
        return filterList();

      case 'My Filters':
        return customList();

      case 'Texture':
        return textureList();

      case 'Light':
        return Column(
          children: [
            adjust('Exposure', settings.exposure, -.8, .8,
                (v) => settings.exposure = v),
            adjust('Contrast', settings.contrast, -.5, .5,
                (v) => settings.contrast = v),
            adjust('Highlights', settings.highlights, -1, 1,
                (v) => settings.highlights = v),
            adjust('Shadows', settings.shadows, -1, 1,
                (v) => settings.shadows = v),
          ],
        );

      case 'Color':
        return Column(
          children: [
            adjust('Saturation', settings.saturation, -1, 1,
                (v) => settings.saturation = v),
            adjust('Temperature', settings.temperature, -.5, .5,
                (v) => settings.temperature = v),
            adjust('Fade', settings.fade, 0, .5,
                (v) => settings.fade = v),
          ],
        );

      case 'Details':
        return Column(
          children: [
            adjust('Sharpen', settings.sharpen, 0, 1,
                (v) => settings.sharpen = v),
            adjust('Vignette', settings.vignette, -1, 1,
                (v) => settings.vignette = v),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget welcome() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const SizedBox(height: 35),
              const Text(
                'LTJ3 / CREATIVE STUDIO',
                style: TextStyle(
                  letterSpacing: 4,
                  color: silver,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                size: 32,
                color: silver,
              ),
              const SizedBox(height: 20),
              const Text(
                'LTJ3',
                style: TextStyle(
                  fontSize: 78,
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Text(
                'E D I T O R',
                style: TextStyle(
                  letterSpacing: 5,
                  color: silver,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'CREATE YOUR OWN VISION',
                style: TextStyle(
                  letterSpacing: 3,
                  fontSize: 11,
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget gallery() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Studio',
                  style: TextStyle(fontSize: 29),
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
          child: photos.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: importPhoto,
                    icon: const Icon(
                      Icons.add_photo_alternate,
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
                  itemCount: photos.length,
                  itemBuilder: (context, i) =>
                      GestureDetector(
                    onTap: () => openPhoto(photos[i]),
                    child: Image.memory(
                      photos[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget editorView() {
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
                  if ((comparing ? before : preview) != null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        (comparing ? before : preview)!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (busy)
                    const Positioned(
                      right: 12,
                      top: 12,
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
          color: dark,
          child: Column(
            children: [
              SizedBox(
                height: 58,
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
                      pill(
                        name,
                        section == name,
                        () => setState(() => section = name),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 245,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: controls(),
                ),
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              settings = Settings();
                            });
                            refreshPreview();
                          },
                    child: const Text('Reset'),
                  ),
                  const Text(
                    'HOLD TO COMPARE',
                    style: TextStyle(
                      fontSize: 10,
                      color: silver,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : exportOptions,
                    child: const Text('Export'),
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
        backgroundColor: black,
        title: const Text(
          'LTJ3 EDITOR',
          style: TextStyle(
            letterSpacing: 3,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            setState(() => editing = false);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          if (editing)
            IconButton(
              onPressed: busy ? null : exportOptions,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: editing ? editorView() : gallery(),
    );
  }
}
