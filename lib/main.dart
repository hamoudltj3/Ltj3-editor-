
import 'dart:convert';
import 'dart:html' as html;
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
const panel = Color(0xFF191919);
const surface = Color(0xFF292929);
const silver = Color(0xFFC8C8C8);
const muted = Color(0xFF888888);

double clamp(num n, double a, double b) =>
    n.clamp(a, b).toDouble();

class Look {
  final String name;
  final double exp, con, sat, temp, fade;

  const Look(
    this.name,
    this.exp,
    this.con,
    this.sat,
    this.temp,
    this.fade,
  );
}

// 20 distinct LTJ3 signature looks.
// Values are stronger than the earlier version.
const looks = <Look>[
  Look('LTJ3 01', .10, .18, .22, .06, 0),
  Look('LTJ3 02', -.15, .30, -.25, -.10, 0),
  Look('LTJ3 03', .15, .13, .35, .13, 0),
  Look('LTJ3 04', .04, -.15, -.30, -.12, .16),
  Look('LTJ3 05', -.20, .38, -.12, -.08, 0),
  Look('LTJ3 06', .20, -.18, -.22, .20, .16),
  Look('LTJ3 07', .10, .27, .40, .09, 0),
  Look('LTJ3 08', -.12, .22, -.40, -.20, .05),
  Look('LTJ3 09', .04, .38, -1, 0, 0),
  Look('LTJ3 10', -.18, .30, -.30, .14, .03),
  Look('LTJ3 11', .14, .28, .24, .10, 0),
  Look('LTJ3 12', -.10, -.12, -.48, .18, .22),
  Look('LTJ3 13', -.20, .25, -.38, -.22, .04),
  Look('LTJ3 14', .17, .20, .19, .24, 0),
  Look('LTJ3 15', -.25, .40, -.45, -.15, 0),
  Look('LTJ3 16', .08, .43, -1, 0, 0),
  Look('LTJ3 17', -.10, .35, .32, -.16, 0),
  Look('LTJ3 18', .18, -.20, -.40, .06, .22),
  Look('LTJ3 19', -.16, .27, -.80, -.10, .05),
  Look('LTJ3 20', -.12, .45, .12, .16, 0),
];

const textureNames = [
  'NONE',
  'FINE GRAIN',
  'FILM HAZE',
  'WARM GLOW',
  'COOL GLOW',
  'ROSE LEAK',
  'SOFT BOKEH',
  'VINTAGE',
];

class Edit {
  int filter = -1;
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
  double sharpen = 0;
  double textureAmount = .45;

  Edit copy() => Edit()
    ..filter = filter
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
    ..sharpen = sharpen
    ..textureAmount = textureAmount;

  Map<String, dynamic> toJson() => {
    'filter': filter,
    'texture': texture,
    'rotation': rotation,
    'flip': flip,
    'ratio': ratio,
    'strength': strength,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'highlights': highlights,
    'shadows': shadows,
    'fade': fade,
    'vignette': vignette,
    'sharpen': sharpen,
    'textureAmount': textureAmount,
  };

  factory Edit.fromJson(Map<String, dynamic> j) {
    double d(String key, double fallback) =>
        (j[key] is num)
            ? (j[key] as num).toDouble()
            : fallback;

    return Edit()
      ..filter = (j['filter'] as num?)?.toInt() ?? -1
      ..texture = (j['texture'] as num?)?.toInt() ?? 0
      ..rotation = (j['rotation'] as num?)?.toInt() ?? 0
      ..flip = j['flip'] == true
      ..ratio = j['ratio']?.toString() ?? 'Original'
      ..strength = d('strength', 1)
      ..exposure = d('exposure', 0)
      ..contrast = d('contrast', 0)
      ..saturation = d('saturation', 0)
      ..temperature = d('temperature', 0)
      ..highlights = d('highlights', 0)
      ..shadows = d('shadows', 0)
      ..fade = d('fade', 0)
      ..vignette = d('vignette', 0)
      ..sharpen = d('sharpen', 0)
      ..textureAmount = d('textureAmount', .45);
  }
}

class SavedLook {
  final String name;
  final Edit settings;

  SavedLook(this.name, this.settings);

  Map<String, dynamic> toJson() => {
    'name': name,
    'settings': settings.toJson(),
  };

  factory SavedLook.fromJson(Map<String, dynamic> j) {
    return SavedLook(
      j['name'].toString(),
      Edit.fromJson(
        Map<String, dynamic>.from(j['settings'] as Map),
      ),
    );
  }
}

// Smooth mathematical helpers.
double smooth(double x) => x * x * (3 - 2 * x);

double hash(int x, int y, int seed) {
  final v = math.sin(
    x * 127.1 + y * 311.7 + seed * 74.7,
  ) * 43758.5453;
  return v - v.floor();
}

double noise(double x, double y, int seed) {
  final ix = x.floor();
  final iy = y.floor();
  final fx = smooth(x - ix);
  final fy = smooth(y - iy);

  final a = hash(ix, iy, seed);
  final b = hash(ix + 1, iy, seed);
  final c = hash(ix, iy + 1, seed);
  final d = hash(ix + 1, iy + 1, seed);

  return (a + (b - a) * fx) * (1 - fy) +
      (c + (d - c) * fx) * fy;
}

double glow(double x, double y, double radius) {
  return math.exp(
    -(x * x + y * y) / (2 * radius * radius),
  );
}

img.Image scaled(img.Image src, int maxSide) {
  if (math.max(src.width, src.height) <= maxSide) {
    return img.Image.from(src);
  }
  return src.width > src.height
      ? img.copyResize(src, width: maxSide)
      : img.copyResize(src, height: maxSide);
}

img.Image process(img.Image original, Edit s) {
  final preset = s.filter >= 0 &&
          s.filter < looks.length
      ? looks[s.filter]
      : null;

  final exposure = clamp(
    s.exposure + (preset?.exp ?? 0) * s.strength,
    -.8,
    .8,
  );
  final contrast = clamp(
    1 + s.contrast +
        (preset?.con ?? 0) * s.strength,
    .45,
    1.75,
  );
  final sat = clamp(
    1 + s.saturation +
        (preset?.sat ?? 0) * s.strength,
    0,
    2,
  );
  final temp = clamp(
    s.temperature +
        (preset?.temp ?? 0) * s.strength,
    -.4,
    .4,
  );
  final fading = clamp(
    s.fade + (preset?.fade ?? 0) * s.strength,
    0,
    .4,
  );

  img.Image out = original.convert(
    format: img.Format.uint8,
    numChannels: 3,
  );

  final w = out.width;
  final h = out.height;
  final gain = math.pow(2, exposure).toDouble();

  for (final p in out) {
    final x = p.x;
    final y = p.y;
    final nx = x / w;
    final ny = y / h;

    double r = p.r / 255;
    double g = p.g / 255;
    double b = p.b / 255;

    final lum = clamp(
      .2126 * r + .7152 * g + .0722 * b,
      0,
      1,
    );

    final shadow = (1 - lum) * (1 - lum);
    final highlight = lum * lum;

    final tone = s.shadows * shadow * .23 +
        s.highlights * highlight * .20;

    r = ((r * gain + tone + temp * .18 - .5) *
            contrast) +
        .5;
    g = ((g * gain + tone - .5) * contrast) + .5;
    b = ((b * gain + tone - temp * .18 - .5) *
            contrast) +
        .5;

    final gray = .2126 * r + .7152 * g + .0722 * b;
    r = gray + (r - gray) * sat;
    g = gray + (g - gray) * sat;
    b = gray + (b - gray) * sat;

    r = r * (1 - fading) + fading * .5;
    g = g * (1 - fading) + fading * .5;
    b = b * (1 - fading) + fading * .5;

    final dx = (nx - .5) * 2;
    final dy = (ny - .5) * 2;
    final radial = clamp(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
      0,
      1,
    );

    final edge = 1 -
        s.vignette *
            math.pow(radial, 2).toDouble() *
            .7;
    r *= edge;
    g *= edge;
    b *= edge;

    final amount = s.textureAmount;

    // Grain: very subtle tonal variation.
    if (s.texture == 1 || s.texture == 7) {
      final variation = hash(x, y, 31) - .5;
      final grain = variation *
          amount *
          (s.texture == 7 ? .09 : .055);
      r += grain;
      g += grain;
      b += grain;
    }

    // Film haze: smooth large-scale texture.
    if (s.texture == 2 || s.texture == 7) {
      final n =
          noise(nx * 4, ny * 4, 13) * .65 +
          noise(nx * 9, ny * 9, 29) * .35;
      final alpha = clamp(
        n * amount * .18,
        0,
        .18,
      );
      r = r * (1 - alpha) + .76 * alpha;
      g = g * (1 - alpha) + .73 * alpha;
      b = b * (1 - alpha) + .70 * alpha;
    }

    // Light leaks: broad, transparent gradients.
    if (s.texture >= 3 && s.texture <= 5) {
      final cx = s.texture == 3
          ? -.10
          : s.texture == 4
              ? 1.10
              : .45;
      final cy = s.texture == 5 ? -.20 : .45;

      final strength = glow(
        nx - cx,
        ny - cy,
        .5,
      ) * amount * .35;

      final cr = s.texture == 4 ? .38 : 1.0;
      final cg = s.texture == 4
          ? .65
          : s.texture == 5
              ? .38
              : .68;
      final cb = s.texture == 4
          ? 1.0
          : s.texture == 5
              ? .72
              : .30;

      r = r * (1 - strength) + cr * strength;
      g = g * (1 - strength) + cg * strength;
      b = b * (1 - strength) + cb * strength;
    }

    // Bokeh: diffuse atmospheric highlights.
    if (s.texture == 6) {
      double light = 0;

      for (int i = 0; i < 6; i++) {
        final bx = hash(i, 2, 30);
        final by = hash(i, 3, 40);
        final radius =
            .035 + hash(i, 5, 50) * .055;

        final dd = math.sqrt(
          math.pow(nx - bx, 2) +
              math.pow(ny - by, 2),
        );

        light += glow(dd, 0, radius) * .12;
      }

      final alpha = clamp(
        light * amount,
        0,
        .22,
      );
      r = r * (1 - alpha) + alpha;
      g = g * (1 - alpha) + alpha * .88;
      b = b * (1 - alpha) + alpha * .70;
    }

    p.r = (clamp(r, 0, 1) * 255).round();
    p.g = (clamp(g, 0, 1) * 255).round();
    p.b = (clamp(b, 0, 1) * 255).round();
  }

  if (s.sharpen > .01) {
    final blurred = img.gaussianBlur(
      out,
      radius: 1,
    );
    final k = s.sharpen * .65;

    for (final p in out) {
      final q = blurred.getPixel(p.x, p.y);
      p.r = clamp(p.r + (p.r - q.r) * k, 0, 255).round();
      p.g = clamp(p.g + (p.g - q.g) * k, 0, 255).round();
      p.b = clamp(p.b + (p.b - q.b) * k, 0, 255).round();
    }
  }

  if (s.flip) {
    out = img.flipHorizontal(out);
  }

  if (s.rotation != 0) {
    out = img.copyRotate(
      out,
      angle: s.rotation * 90,
    );
  }

  final ratios = <String, double>{
    '1:1': 1,
    '4:5': .8,
    '3:4': .75,
    '9:16': 9 / 16,
    '16:9': 16 / 9,
  };

  if (ratios.containsKey(s.ratio)) {
    final ratio = ratios[s.ratio]!;
    var cw = out.width;
    var ch = out.height;

    if (cw / ch > ratio) {
      cw = (ch * ratio).round();
    } else {
      ch = (cw / ratio).round();
    }

    out = img.copyCrop(
      out,
      x: (out.width - cw) ~/ 2,
      y: (out.height - ch) ~/ 2,
      width: cw,
      height: ch,
    );
  }

  return out;
}

class LTJ3App extends StatelessWidget {
  const LTJ3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LTJ3 EDITOR',
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.white,
          inactiveTrackColor: surface,
          thumbColor: Colors.white,
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

  bool started = false;
  bool gallery = true;
  bool busy = false;
  bool comparing = false;

  String tab = 'Filters';

  final photos = <Uint8List>[];
  final custom = <SavedLook>[];
  final undoHistory = <Edit>[];
  final redoHistory = <Edit>[];

  img.Image? original;
  img.Image? previewSource;
  Uint8List? originalPreview;
  Uint8List? currentPreview;

  List<Uint8List?> filterThumbs =
      List.filled(21, null);
  List<Uint8List?> textureThumbs =
      List.filled(textureNames.length, null);

  Edit edit = Edit();
  Edit? sliderBefore;

  @override
  void initState() {
    super.initState();
    loadCustom();
  }

  void notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void loadCustom() {
    try {
      final raw =
          html.window.localStorage['ltj3_custom_v7'];

      if (raw == null) return;

      final items = jsonDecode(raw) as List;

      custom.clear();

      for (final item in items) {
        custom.add(
          SavedLook.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        );
      }
    } catch (_) {
      custom.clear();
    }
  }

  void persistCustom() {
    try {
      html.window.localStorage['ltj3_custom_v7'] =
          jsonEncode(
        custom.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      notify('Unable to store custom filters');
    }
  }

  void remember() {
    undoHistory.add(edit.copy());
    if (undoHistory.length > 30) {
      undoHistory.removeAt(0);
    }
    redoHistory.clear();
  }

  void change(VoidCallback callback) {
    if (busy) return;
    remember();
    setState(callback);
    updatePreview();
  }

  void undo() {
    if (busy || undoHistory.isEmpty) return;
    redoHistory.add(edit.copy());
    setState(() => edit = undoHistory.removeLast());
    updatePreview();
  }

  void redo() {
    if (busy || redoHistory.isEmpty) return;
    undoHistory.add(edit.copy());
    setState(() => edit = redoHistory.removeLast());
    updatePreview();
  }

  Future<void> importImages() async {
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
        await openImage(loaded.first);
      }
    } catch (_) {
      notify('Could not import photos');
    }
  }

  Future<void> openImage(Uint8List bytes) async {
    if (busy) return;
    setState(() => busy = true);

    try {
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Unsupported image');
      }

      decoded = img.bakeOrientation(decoded);

      final large = scaled(decoded, 1200);
      // Higher-resolution filter thumbnails.
      final thumb = scaled(decoded, 280);

      final thumbs = <Uint8List?>[];

      thumbs.add(
        Uint8List.fromList(
          img.encodeJpg(thumb, quality: 95),
        ),
      );

      for (int i = 0; i < 20; i++) {
        final state = Edit()..filter = i;

        thumbs.add(
          Uint8List.fromList(
            img.encodeJpg(
              process(thumb, state),
              quality: 94,
            ),
          ),
        );
      }

      final effects = <Uint8List?>[];

      for (int i = 0; i < textureNames.length; i++) {
        final state = Edit()
          ..texture = i
          ..textureAmount = .85;

        effects.add(
          Uint8List.fromList(
            img.encodeJpg(
              process(thumb, state),
              quality: 93,
            ),
          ),
        );
      }

      final clean = Uint8List.fromList(
        img.encodeJpg(large, quality: 96),
      );

      if (!mounted) return;

      setState(() {
        original = decoded;
        previewSource = large;
        originalPreview = clean;
        currentPreview = clean;
        filterThumbs = thumbs;
        textureThumbs = effects;
        edit = Edit();
        undoHistory.clear();
        redoHistory.clear();
        gallery = false;
        tab = 'Filters';
      });
    } catch (_) {
      notify('Unable to open photo');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updatePreview() async {
    if (previewSource == null || busy) return;
    setState(() => busy = true);

    try {
      final result = process(
        previewSource!,
        edit.copy(),
      );
      final bytes = Uint8List.fromList(
        img.encodeJpg(result, quality: 96),
      );

      if (mounted) {
        setState(() => currentPreview = bytes);
      }
    } catch (_) {
      notify('Preview processing failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveCustomFilter() async {
    if (original == null) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('CREATE YOUR FILTER'),
        content: TextField(
          controller: controller,
          maxLength: 32,
          autofocus: true,
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
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    setState(() {
      custom.add(SavedLook(name, edit.copy()));
      tab = 'My Filters';
    });

    persistCustom();
    notify('Filter saved: $name');
  }

  void applyCustom(SavedLook saved) {
    change(() {
      edit = saved.settings.copy();
    });
  }

  void deleteCustom(int index) {
    setState(() {
      custom.removeAt(index);
    });
    persistCustom();
  }

  Future<void> exportPhoto(bool png) async {
    if (original == null || busy) return;
    setState(() => busy = true);

    try {
      final result = process(original!, edit.copy());

      final bytes = Uint8List.fromList(
        png
            ? img.encodePng(result)
            : img.encodeJpg(result, quality: 100),
      );

      final name = png
          ? 'LTJ3_ULTRA_HD.png'
          : 'LTJ3_ULTRA_HD.jpg';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: name,
            mimeType: png
                ? 'image/png'
                : 'image/jpeg',
          ),
        ],
        fileNameOverrides: [name],
      );
    } catch (_) {
      notify(
        'Export failed. Try JPEG or a smaller photo.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showExport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 16),
              ListTile(
                title: const Text('JPEG MAX QUALITY'),
                subtitle: const Text('Quality 100'),
                leading: const Icon(Icons.image_outlined),
                onTap: () {
                  Navigator.pop(sheetContext);
                  exportPhoto(false);
                },
              ),
              ListTile(
                title: const Text('PNG LOSSLESS'),
                subtitle:
                    const Text('Lossless PNG compression'),
                leading: const Icon(Icons.high_quality),
                onTap: () {
                  Navigator.pop(sheetContext);
                  exportPhoto(true);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget pill(
    String text,
    bool selected,
    VoidCallback tap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          backgroundColor:
              selected ? const Color(0xFF454545) : surface,
          foregroundColor:
              selected ? Colors.white : muted,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          shape: const StadiumBorder(),
        ),
        child: Text(text),
      ),
    );
  }

  Widget slider(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> callback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              title,
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
              value: clamp(value, min, max),
              onChangeStart: (_) {
                sliderBefore = edit.copy();
              },
              onChanged: busy
                  ? null
                  : (v) => setState(() => callback(v)),
              onChangeEnd: (_) {
                if (sliderBefore != null) {
                  undoHistory.add(sliderBefore!);
                  redoHistory.clear();
                  sliderBefore = null;
                }
                updatePreview();
              },
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 11,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget welcome() {
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
                'LTJ3 / CREATIVE STUDIO',
                style: TextStyle(
                  color: silver,
                  fontSize: 11,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                color: silver,
                size: 30,
              ),
              const SizedBox(height: 22),
              const Text(
                'LTJ3',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 5,
                ),
              ),
              const Text(
                'E D I T O R',
                style: TextStyle(
                  color: silver,
                  fontSize: 15,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                height: 1,
                width: 70,
                color: Colors.white38,
              ),
              const SizedBox(height: 30),
              const Text(
                'CREATE YOUR OWN VISION.',
                style: TextStyle(
                  color: silver,
                  fontSize: 12,
                  letterSpacing: 2,
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
                      gallery = true;
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
              const SizedBox(height: 25),
              const Text(
                'CREATE · REFINE · EXPORT',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
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

  Widget galleryView() {
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
                    fontFamily: 'Georgia',
                    fontSize: 30,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: importImages,
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
                    onPressed: importImages,
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
                    onTap: () => openImage(photos[i]),
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

  Widget filtersPanel() {
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
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 21,
            itemBuilder: (context, index) {
              final active = edit.filter == index - 1;

              return GestureDetector(
                onTap: () {
                  change(() => edit.filter = index - 1);
                },
                child: Container(
                  width: 103,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: active
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
                      const SizedBox(height: 7),
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
        slider(
          'Intensity',
          edit.strength,
          0,
          1.5,
          (v) => edit.strength = v,
        ),
      ],
    );
  }

  Widget texturePanel() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'LTJ3 TEXTURE STUDIO',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 11,
            color: silver,
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: textureNames.length,
            itemBuilder: (context, i) {
              final selected = edit.texture == i;

              return GestureDetector(
                onTap: () {
                  change(() => edit.texture = i);
                },
                child: Container(
                  width: 99,
                  margin: const EdgeInsets.only(right: 9),
                  child: Column(
                    children: [
                      Container(
                        width: 95,
                        height: 94,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : surface,
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
                      const SizedBox(height: 7),
                      Text(
                        textureNames[i],
                        style: const TextStyle(
                          fontSize: 9,
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
        slider(
          'Texture',
          edit.textureAmount,
          0,
          1,
          (v) => edit.textureAmount = v,
        ),
      ],
    );
  }

  Widget customPanel() {
    return Column(
      children: [
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saveCustomFilter,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('SAVE CURRENT LOOK'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
        const SizedBox(height: 14),
        if (custom.isEmpty)
          const Text(
            'Your saved filters appear here.',
            style: TextStyle(color: muted),
          ),
        for (int i = 0; i < custom.length; i++)
          ListTile(
            leading: const Icon(
              Icons.auto_awesome,
              color: silver,
            ),
            title: Text(custom[i].name),
            subtitle: const Text('CUSTOM LTJ3 FILTER'),
            onTap: () => applyCustom(custom[i]),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: muted,
              ),
              onPressed: () => deleteCustom(i),
            ),
          ),
      ],
    );
  }

  Widget toolsPanel() {
    switch (tab) {
      case 'Filters':
        return filtersPanel();

      case 'My Filters':
        return customPanel();

      case 'Texture':
        return texturePanel();

      case 'Light':
        return Column(
          children: [
            slider('Exposure', edit.exposure, -.8, .8,
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
            slider('Temperature', edit.temperature, -.4, .4,
                (v) => edit.temperature = v),
            slider('Saturation', edit.saturation, -1, 1,
                (v) => edit.saturation = v),
            slider('Fade', edit.fade, 0, .4,
                (v) => edit.fade = v),
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

      case 'Crop':
        return Column(
          children: [
            SizedBox(
              height: 55,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ratio in [
                    'Original', '1:1', '4:5',
                    '3:4', '9:16', '16:9',
                  ])
                    pill(
                      ratio,
                      edit.ratio == ratio,
                      () => change(
                        () => edit.ratio = ratio,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => change(
                    () => edit.rotation =
                        (edit.rotation + 3) % 4,
                  ),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton(
                  onPressed: () => change(
                    () => edit.rotation =
                        (edit.rotation + 1) % 4,
                  ),
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  onPressed: () => change(
                    () => edit.flip = !edit.flip,
                  ),
                  icon: const Icon(Icons.flip),
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
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
                  if ((comparing
                          ? originalPreview
                          : currentPreview) !=
                      null)
                    InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        (comparing
                            ? originalPreview
                            : currentPreview)!,
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
                height: 62,
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
                      'Crop',
                    ])
                      pill(
                        name,
                        tab == name,
                        () => setState(() => tab = name),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 245,
                child: SingleChildScrollView(
                  child: toolsPanel(),
                ),
              ),
              const Divider(color: surface, height: 1),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => change(
                              () => edit = Edit(),
                            ),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                  const Text(
                    'HOLD TO COMPARE',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: muted,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : showExport,
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
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            setState(() => gallery = true);
          },
          icon: Icon(
            gallery
                ? Icons.grid_view
                : Icons.arrow_back_ios_new,
          ),
        ),
        actions: [
          if (!gallery)
            IconButton(
              onPressed: busy || undoHistory.isEmpty
                  ? null
                  : undo,
              icon: const Icon(Icons.undo),
            ),
          if (!gallery)
            IconButton(
              onPressed: busy || redoHistory.isEmpty
                  ? null
                  : redo,
              icon: const Icon(Icons.redo),
            ),
          if (!gallery)
            IconButton(
              onPressed: busy ? null : showExport,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: gallery ? galleryView() : editorView(),
    );
  }
}
