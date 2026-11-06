
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// LTJ3 EDITOR — NEBULA EDITION
// Replace lib/main.dart only. All photo processing happens on the device.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NebulaApp());
}

const ink = Color(0xFF05090B);
const surface = Color(0xFF111A1D);
const raised = Color(0xFF1C282C);
const mint = Color(0xFF55EAD8);
const soft = Color(0xFFC5D5D7);
const dim = Color(0xFF829699);

double cap(num x, [double low = 0, double high = 1]) => x.clamp(low, high).toDouble();

class Signature {
  final String name;
  final double light, contrast, saturation, warmth, fade, blueShadows, goldHighlights;
  const Signature(this.name, this.light, this.contrast, this.saturation,
      this.warmth, this.fade, this.blueShadows, this.goldHighlights);
}

// Every signature uses a different color recipe and tonal curve.
const signatures = <Signature>[
  Signature('EMBER DRIVE', .09, .23, .32, .24, .01, -.06, .23),
  Signature('CYAN PULSE', -.04, .32, .32, -.20, 0, .37, -.04),
  Signature('GOLDEN VELVET', .06, .12, .18, .24, .12, -.08, .34),
  Signature('MIDNIGHT POP', -.17, .41, .34, -.14, .01, .32, .13),
  Signature('LTJ3 NOIR', -.03, .39, -1, 0, 0, 0, 0),
  Signature('SOLAR FLARE', .18, .09, .25, .28, .09, -.07, .39),
  Signature('VIOLET HOUR', -.10, .22, .19, -.14, .07, .34, .06),
  Signature('COCOA FILM', -.08, .19, -.36, .26, .15, -.12, .20),
  Signature('ARCTIC GLASS', .12, .16, -.14, -.27, .05, .40, -.13),
  Signature('REDLINE', -.08, .35, .45, .19, 0, -.09, .29),
  Signature('VELVET FADE', .12, -.19, -.24, .16, .28, .05, .09),
  Signature('STREET CHROME', -.14, .45, -.23, -.11, 0, .20, -.01),
  Signature('DESERT GOLD', .05, .20, .25, .30, .08, -.21, .31),
  Signature('MOON DUST', -.13, .30, -.63, -.19, .09, .29, -.13),
  Signature('NEON NIGHTS', -.13, .40, .56, -.12, 0, .42, .19),
  Signature('SOFT PEARL', .20, -.22, -.30, .06, .26, .10, .11),
  Signature('FOREST CODE', -.11, .29, .07, -.20, .03, .18, -.18),
  Signature('MARS 35', -.15, .33, .31, .27, .02, -.19, .42),
  Signature('SILVER GHOST', .09, .22, -.96, -.03, .16, .08, .01),
  Signature('AFTER DARK', -.23, .45, .07, -.05, .02, .29, .16),
];

const textureLabels = <String>[
  'NONE', 'FINE GRAIN', 'DUST STORM', 'NEON LEAK', 'PRISM FOG',
  'STARDUST', 'AMBER EDGE', 'COBALT EDGE', 'ROSE GLOW', 'SUNSET FILM',
  'SOFT BOKEH', 'GOLDEN BOKEH', 'BLUE BOKEH', 'FROST HAZE',
  'VINTAGE DUST', 'GOLD MIST', 'PURPLE MIST', 'LIGHT WINDOW',
  'FILM WASH', 'MONO GRAIN',
];

class Edits {
  Edits();
  int filter = -1;
  int texture = 0;
  double intensity = 1;
  double exposure = 0;
  double contrast = 0;
  double saturation = 0;
  double warmth = 0;
  double highlights = 0;
  double shadows = 0;
  double fade = 0;
  double sharpen = 0;
  double vignette = 0;
  double textureAmount = .65;
  double clarity = 0;
  double vibrance = 0;
  double grain = 0;

  Edits copy() => Edits()
    ..filter = filter ..texture = texture ..intensity = intensity
    ..exposure = exposure ..contrast = contrast ..saturation = saturation
    ..warmth = warmth ..highlights = highlights ..shadows = shadows
    ..fade = fade ..sharpen = sharpen ..vignette = vignette
    ..textureAmount = textureAmount ..clarity = clarity
    ..vibrance = vibrance ..grain = grain;

  Map<String, dynamic> toJson() => {
    'filter': filter, 'texture': texture, 'intensity': intensity,
    'exposure': exposure, 'contrast': contrast, 'saturation': saturation,
    'warmth': warmth, 'highlights': highlights, 'shadows': shadows,
    'fade': fade, 'sharpen': sharpen, 'vignette': vignette,
    'textureAmount': textureAmount, 'clarity': clarity,
    'vibrance': vibrance, 'grain': grain,
  };

  factory Edits.fromJson(Map<String, dynamic> v) {
    double read(String a, double fallback) =>
        v[a] is num ? (v[a] as num).toDouble() : fallback;

    // Older LTJ3 filters used strength, temperature, texturePower.
    return Edits()
      ..filter = read('filter', -1).toInt()
      ..texture = read('texture', 0).toInt()
      ..intensity = read('intensity', read('strength', 1))
      ..exposure = read('exposure', 0)
      ..contrast = read('contrast', 0)
      ..saturation = read('saturation', 0)
      ..warmth = read('warmth', read('temperature', 0))
      ..highlights = read('highlights', 0)
      ..shadows = read('shadows', 0)
      ..fade = read('fade', 0)
      ..sharpen = read('sharpen', 0)
      ..vignette = read('vignette', 0)
      ..textureAmount = read('textureAmount', read('texturePower', .65))
      ..clarity = read('clarity', 0)
      ..vibrance = read('vibrance', 0)
      ..grain = read('grain', 0);
  }
}

double rnd(int x, int y, int seed) {
  final n = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453;
  return n - n.floorToDouble();
}

double glow(double dx, double dy, double radius) =>
    math.exp(-(dx * dx + dy * dy) / (2 * radius * radius));

im.Image scaled(im.Image src, int longest) {
  if (math.max(src.width, src.height) <= longest) {
    return im.copyResize(src, width: src.width, height: src.height);
  }
  return src.width >= src.height
      ? im.copyResize(src, width: longest)
      : im.copyResize(src, height: longest);
}

im.Image render(im.Image src, Edits e) {
  final sig = e.filter >= 0 && e.filter < signatures.length
      ? signatures[e.filter] : null;
  final level = e.intensity;
  final ex = cap(e.exposure + (sig?.light ?? 0) * level, -.85, .85);
  final ct = cap(1 + e.contrast + (sig?.contrast ?? 0) * level, .45, 1.75);
  final st = cap(1 + e.saturation + (sig?.saturation ?? 0) * level, 0, 2);
  final wt = cap(e.warmth + (sig?.warmth ?? 0) * level, -.6, .6);
  final fd = cap(e.fade + (sig?.fade ?? 0) * level, 0, .6);
  final blue = (sig?.blueShadows ?? 0) * level;
  final gold = (sig?.goldHighlights ?? 0) * level;
  final gain = math.pow(2, ex).toDouble();
  final out = src.convert(format: im.Format.uint8, numChannels: 3);
  final w = out.width.toDouble(), h = out.height.toDouble();

  for (final p in out) {
    final nx = p.x / w, ny = p.y / h;
    double r = p.r / 255, g = p.g / 255, b = p.b / 255;

    final lum = cap(.2126 * r + .7152 * g + .0722 * b);
    final sw = (1 - lum) * (1 - lum), hw = lum * lum;
    final tone = e.shadows * sw * .23 + e.highlights * hw * .20;

    r = (r * gain + tone + wt * .19 - .5) * ct + .5;
    g = (g * gain + tone - .5) * ct + .5;
    b = (b * gain + tone - wt * .19 - .5) * ct + .5;

    // Signature split-toning gives a distinct color identity.
    r += gold * hw * .22 - blue * sw * .11;
    g += gold * hw * .09 + blue * sw * .12;
    b -= gold * hw * .14 - blue * sw * .25;

    final gray = .2126 * r + .7152 * g + .0722 * b;
    final vib = 1 +
        e.vibrance * (1 - cap((r - g).abs() + (b - g).abs()));
    final saturation = st * vib;

    r = gray + (r - gray) * saturation;
    g = gray + (g - gray) * saturation;
    b = gray + (b - gray) * saturation;

    r = r * (1 - fd) + fd * .54;
    g = g * (1 - fd) + fd * .52;
    b = b * (1 - fd) + fd * .49;

    final dx = (nx - .5) * 2, dy = (ny - .5) * 2;
    final edge = cap(
      math.sqrt(dx * dx + dy * dy) / math.sqrt2,
    );
    final shade = 1 - e.vignette * edge * edge * .64;
    r *= shade;
    g *= shade;
    b *= shade;

    final amt = e.textureAmount;
    final tex = e.texture;

    if (tex == 1 ||
        tex == 2 ||
        tex == 5 ||
        tex == 14 ||
        tex == 19 ||
        e.grain > 0) {
      final fine = (rnd(p.x, p.y, 31) - .5) *
          ((tex == 1 || tex == 19
                  ? .075
                  : tex == 2
                      ? .055
                      : .028) *
              amt +
              e.grain * .065);
      r += fine;
      g += fine;
      b += fine;
    }

    if (tex == 2 || tex == 5 || tex == 14) {
      final dust = rnd(p.x ~/ 3, p.y ~/ 3, 43);
      if (dust > .996 - amt * .004) {
        final alpha = amt * (tex == 2 ? .24 : .17);
        r += alpha;
        g += alpha;
        b += alpha;
      }
    }

    if (tex == 3 ||
        tex == 6 ||
        tex == 7 ||
        tex == 8 ||
        tex == 9 ||
        tex == 17) {
      final right = tex == 7 || tex == 8;
      final centerX = right ? 1.12 : -.14;
      final centerY = tex == 17 ? -.18 : .41;
      final light = cap(
        glow(
              nx - centerX,
              ny - centerY,
              tex == 17 ? .4 : .6,
            ) *
            amt *
            .65,
      );
      final cr = tex == 7
          ? .22
          : tex == 8
              ? 1.0
              : tex == 3
                  ? .15
                  : 1.0;
      final cg = tex == 7
          ? .58
          : tex == 8
              ? .35
              : tex == 3
                  ? .82
                  : tex == 9
                      ? .42
                      : .68;
      final cb = tex == 7
          ? 1.0
          : tex == 8
              ? .63
              : tex == 3
                  ? .75
                  : .17;

      r = r * (1 - light) + cr * light;
      g = g * (1 - light) + cg * light;
      b = b * (1 - light) + cb * light;
    }

    if (tex == 4 ||
        tex == 13 ||
        tex == 15 ||
        tex == 16 ||
        tex == 18) {
      final haze =
          glow(nx - .5, ny - .55, .65) * amt * .28;
      final cr = tex == 16 ? .62 : tex == 15 ? .9 : .77;
      final cg = tex == 16 ? .45 : tex == 13 ? .88 : .76;
      final cb = tex == 16 ? .95 : tex == 13 ? 1.0 : .66;

      r = r * (1 - haze) + cr * haze;
      g = g * (1 - haze) + cg * haze;
      b = b * (1 - haze) + cb * haze;
    }

    if (tex == 10 || tex == 11 || tex == 12) {
      for (int i = 0; i < 7; i++) {
        final bx = rnd(i, 13, 3), by = rnd(i, 9, 4);
        final radius = .017 + rnd(i, 5, 7) * .043;
        final dot = glow(
              nx - bx,
              ny - by,
              radius,
            ) *
            amt *
            .18;
        r += dot * (tex == 12 ? .35 : 1);
        g += dot * (tex == 12 ? .65 : .83);
        b += dot * (tex == 12 ? 1 : .57);
      }
    }

    p.r = (cap(r) * 255).round();
    p.g = (cap(g) * 255).round();
    p.b = (cap(b) * 255).round();
  }

  if (e.sharpen > .01 || e.clarity > .01) {
    final blurred = im.gaussianBlur(out, radius: 1);
    final amount = e.sharpen * .48 + e.clarity * .22;
    for (final p in out) {
      final b = blurred.getPixel(p.x, p.y);
      p.r = cap(
        p.r + (p.r - b.r) * amount,
        0,
        255,
      ).round();
      p.g = cap(
        p.g + (p.g - b.g) * amount,
        0,
        255,
      ).round();
      p.b = cap(
        p.b + (p.b - b.b) * amount,
        0,
        255,
      ).round();
    }
  }
  return out;
}

class NebulaApp extends StatelessWidget {
  const NebulaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LTJ3 EDITOR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: ink,
          colorScheme: const ColorScheme.dark(
            primary: mint,
            onPrimary: ink,
            surface: surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: ink,
            foregroundColor: Colors.white,
          ),
          sliderTheme: const SliderThemeData(
            activeTrackColor: mint,
            inactiveTrackColor: Color(0xFF314449),
            thumbColor: mint,
            trackHeight: 3,
          ),
        ),
        home: const NebulaStudio(),
      );
}

class NebulaStudio extends StatefulWidget {
  const NebulaStudio({super.key});

  @override
  State<NebulaStudio> createState() => _NebulaStudioState();
}

class _NebulaStudioState extends State<NebulaStudio> {
  final picker = ImagePicker();
  final photos = <Uint8List>[];
  final saved = <String, Edits>{};
  final thumb = <Uint8List>[];
  final customThumb = <String, Uint8List>{};
  final textureThumb = <Uint8List>[];

  Edits edits = Edits();
  im.Image? original, previewSource;
  Uint8List? before, after;

  bool started = false;
  bool editorOpen = false;
  bool processing = false;
  bool comparing = false;

  String section = 'Filters';
  int sequence = 0;

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  void toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void loadSaved() {
    // Preserve V9 custom filters.
    try {
      final raw =
          html.window.localStorage['ltj3_v9_filters'];
      if (raw == null) return;

      final json = jsonDecode(raw) as Map;
      for (final entry in json.entries) {
        saved[entry.key.toString()] = Edits.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    } catch (_) {
      // Ignore damaged browser storage.
    }
  }

  void storeSaved() {
    try {
      html.window.localStorage['ltj3_v9_filters'] =
          jsonEncode(
        saved.map(
          (key, value) =>
              MapEntry(key, value.toJson()),
        ),
      );
    } catch (_) {
      toast('Local storage unavailable');
    }
  }

  Uint8List jpg(im.Image x, [int quality = 96]) =>
      Uint8List.fromList(
        im.encodeJpg(x, quality: quality),
      );

  Future<void> importImages() async {
    if (processing) return;

    try {
      final files = await picker.pickMultiImage(
        imageQuality: 100,
      );

      if (files.isEmpty) return;

      final incoming = <Uint8List>[];

      for (final f in files) {
        incoming.add(await f.readAsBytes());
      }

      if (!mounted) return;

      setState(() => photos.addAll(incoming));
      await openImage(incoming.first);
    } catch (_) {
      toast('Unable to import photos');
    }
  }

  Future<void> openImage(Uint8List bytes) async {
    if (processing) return;

    setState(() => processing = true);

    try {
      var decoded = im.decodeImage(bytes);

      if (decoded == null) {
        throw StateError('Unsupported format');
      }

      decoded = im.bakeOrientation(decoded);

      final preview = scaled(decoded, 1500);
      final small = scaled(decoded, 330);
      final textureSmall = scaled(decoded, 220);

      final newThumb = <Uint8List>[jpg(small)];

      for (var i = 0; i < signatures.length; i++) {
        newThumb.add(
          jpg(
            render(small, Edits()..filter = i),
            95,
          ),
        );
      }

      final newCustom = <String, Uint8List>{};

      for (final item in saved.entries) {
        newCustom[item.key] = jpg(
          render(small, item.value.copy()),
          95,
        );
      }

      final newTexture = <Uint8List>[];

      for (var i = 0; i < textureLabels.length; i++) {
        newTexture.add(
          jpg(
            render(
              textureSmall,
              Edits()..texture = i,
            ),
            91,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        original = decoded;
        previewSource = preview;
        before = jpg(preview);
        after = before;
        edits = Edits();
        section = 'Filters';
        editorOpen = true;

        thumb
          ..clear()
          ..addAll(newThumb);

        customThumb
          ..clear()
          ..addAll(newCustom);

        textureThumb
          ..clear()
          ..addAll(newTexture);
      });
    } catch (_) {
      toast('Could not open this photo');
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  Future<void> refresh() async {
    if (previewSource == null || processing) return;

    final id = ++sequence;
    setState(() => processing = true);

    try {
      final bytes = jpg(
        render(
          previewSource!,
          edits.copy(),
        ),
      );

      if (mounted && id == sequence) {
        setState(() => after = bytes);
      }
    } catch (_) {
      toast('Preview failed');
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  void selectFilter(int i) {
    if (processing) return;
    setState(() => edits.filter = i);
    refresh();
  }

  void selectTexture(int i) {
    if (processing) return;
    setState(() => edits.texture = i);
    refresh();
  }

  Future<void> nameAndSave() async {
    if (original == null || processing) {
      toast('Import a photo first');
      return;
    }

    final field = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: const Text('SAVE YOUR SIGNATURE'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 28,
          decoration: const InputDecoration(
            labelText: 'Filter name',
            hintText: 'Night Rebel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              field.text.trim(),
            ),
            child: const Text('Save Filter'),
          ),
        ],
      ),
    );

    field.dispose();

    if (!mounted || name == null || name.isEmpty) {
      return;
    }

    saved[name] = edits.copy();

    if (previewSource != null) {
      customThumb[name] = jpg(
        render(
          scaled(previewSource!, 330),
          edits.copy(),
        ),
      );
    }

    storeSaved();

    setState(() => section = 'Filters');
    toast('$name saved to your filters');
  }

  Future<void> export(bool png) async {
    if (processing || original == null) return;

    setState(() => processing = true);

    try {
      final result = render(
        original!,
        edits.copy(),
      );

      final bytes = Uint8List.fromList(
        png
            ? im.encodePng(result)
            : im.encodeJpg(result, quality: 100),
      );

      final filename =
          'LTJ3_NEBULA_${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';

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
      toast(
        'Export failed — try a smaller image or JPEG',
      );
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  void exportOptions() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: surface,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('NEBULA EXPORT'),
                subtitle: Text(
                  'Full source resolution when memory permits',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.image,
                  color: mint,
                ),
                title: const Text(
                  'JPEG — MAX QUALITY',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  export(false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.high_quality,
                  color: mint,
                ),
                title: const Text(
                  'PNG — LOSSLESS',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  export(true);
                },
              ),
            ],
          ),
        ),
      );

  BoxDecoration glass({
    bool highlighted = false,
    double radius = 20,
  }) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlighted
              ? [
                  const Color(0xFF063B39),
                  const Color(0xFF07191C),
                ]
              : [raised, surface],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted
              ? mint
              : const Color(0xFF304145),
          width: highlighted ? 1.4 : .8,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: mint.withAlpha(35),
                  blurRadius: 17,
                ),
              ]
            : [],
      );

  Widget pill(
    String text,
    bool active,
    VoidCallback action,
  ) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton(
          onPressed: action,
          style: TextButton.styleFrom(
            backgroundColor: active ? mint : raised,
            foregroundColor: active ? ink : soft,
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 13,
            ),
            shape: const StadiumBorder(),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: active
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget slider(
    String label,
    double value,
    double low,
    double high,
    ValueChanged<double> change,
  ) =>
      Row(
        children: [
          SizedBox(
            width: 93,
            child: Text(
              label,
              style: const TextStyle(
                color: soft,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: cap(value, low, high),
              min: low,
              max: high,
              onChanged: processing
                  ? null
                  : (v) => setState(
                        () => change(v),
                      ),
              onChangeEnd: (_) => refresh(),
            ),
          ),
          SizedBox(
            width: 43,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: mint,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );

  Widget photoTile(
    String label,
    Uint8List? bytes,
    bool selected,
    VoidCallback tap, {
    VoidCallback? onLongPress,
  }) =>
      GestureDetector(
        onTap: tap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 108,
          child: Column(
            children: [
              Container(
                width: 98,
                height: 113,
                clipBehavior: Clip.antiAlias,
                decoration: glass(
                  highlighted: selected,
                  radius: 13,
                ),
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      )
                    : const Icon(
                        Icons.auto_awesome,
                        color: mint,
                      ),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? mint : soft,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      );

  Widget filterControls() => Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            'LTJ3 SIGNATURE COLLECTION',
            style: TextStyle(
              fontSize: 10,
              color: soft,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 151,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: nameAndSave,
                  child: SizedBox(
                    width: 108,
                    child: Column(
                      children: [
                        Container(
                          width: 98,
                          height: 113,
                          decoration: glass(
                            highlighted: true,
                            radius: 13,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: mint,
                            size: 37,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'CREATE FILTER',
                          style: TextStyle(
                            color: mint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final name in saved.keys.toList())
                  photoTile(
                    name,
                    customThumb[name],
                    false,
                    () {
                      if (processing) return;
                      setState(
                        () => edits = saved[name]!.copy(),
                      );
                      refresh();
                    },
                    onLongPress: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete $name?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                saved.remove(name);
                                customThumb.remove(name);
                              });
                              storeSaved();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (thumb.isNotEmpty)
                  photoTile(
                    'ORIGINAL',
                    thumb[0],
                    edits.filter == -1,
                    () => selectFilter(-1),
                  ),
                for (int i = 0;
                    i < signatures.length &&
                        i + 1 < thumb.length;
                    i++)
                  photoTile(
                    signatures[i].name,
                    thumb[i + 1],
                    edits.filter == i,
                    () => selectFilter(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          slider(
            'Intensity',
            edits.intensity,
            0,
            1.5,
            (v) => edits.intensity = v,
          ),
        ],
      );

  Widget textureControls() => Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            'LTJ3 TEXTURE LAB',
            style: TextStyle(
              fontSize: 10,
              color: soft,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 151,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0;
                    i < textureLabels.length &&
                        i < textureThumb.length;
                    i++)
                  photoTile(
                    textureLabels[i],
                    textureThumb[i],
                    edits.texture == i,
                    () => selectTexture(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          slider(
            'Strength',
            edits.textureAmount,
            0,
            1,
            (v) => edits.textureAmount = v,
          ),
        ],
      );

  Widget tools() {
    switch (section) {
      case 'Filters':
        return filterControls();

      case 'Texture':
        return textureControls();

      case 'Light':
        return Column(
          children: [
            slider(
              'Exposure',
              edits.exposure,
              -.85,
              .85,
              (v) => edits.exposure = v,
            ),
            slider(
              'Contrast',
              edits.contrast,
              -.5,
              .6,
              (v) => edits.contrast = v,
            ),
            slider(
              'Highlights',
              edits.highlights,
              -1,
              1,
              (v) => edits.highlights = v,
            ),
            slider(
              'Shadows',
              edits.shadows,
              -1,
              1,
              (v) => edits.shadows = v,
            ),
            slider(
              'Fade',
              edits.fade,
              0,
              .6,
              (v) => edits.fade = v,
            ),
          ],
        );

      case 'Color':
        return Column(
          children: [
            slider(
              'Saturation',
              edits.saturation,
              -1,
              1,
              (v) => edits.saturation = v,
            ),
            slider(
              'Vibrance',
              edits.vibrance,
              -1,
              1,
              (v) => edits.vibrance = v,
            ),
            slider(
              'Warmth',
              edits.warmth,
              -.6,
              .6,
              (v) => edits.warmth = v,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('WARM'),
                  onPressed: processing
                      ? null
                      : () {
                          setState(
                            () => edits.warmth = .24,
                          );
                          refresh();
                        },
                ),
                ActionChip(
                  label: const Text('COOL'),
                  onPressed: processing
                      ? null
                      : () {
                          setState(
                            () => edits.warmth = -.23,
                          );
                          refresh();
                        },
                ),
                ActionChip(
                  label: const Text('NATURAL'),
                  onPressed: processing
                      ? null
                      : () {
                          setState(
                            () => edits.warmth = 0,
                          );
                          refresh();
                        },
                ),
              ],
            ),
          ],
        );

      case 'Details':
        return Column(
          children: [
            slider(
              'Clarity',
              edits.clarity,
              0,
              1,
              (v) => edits.clarity = v,
            ),
            slider(
              'Sharpen',
              edits.sharpen,
              0,
              1,
              (v) => edits.sharpen = v,
            ),
            slider(
              'Film grain',
              edits.grain,
              0,
              1,
              (v) => edits.grain = v,
            ),
            slider(
              'Vignette',
              edits.vignette,
              -1,
              1,
              (v) => edits.vignette = v,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget welcome() => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 27,
            ),
            child: Column(
              children: [
                const SizedBox(height: 36),
                const Text(
                  'LTJ3 / CREATIVE UNIVERSE',
                  style: TextStyle(
                    color: soft,
                    letterSpacing: 3,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 110,
                  height: 110,
                  decoration: glass(
                    highlighted: true,
                    radius: 40,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: mint,
                    size: 51,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'LTJ3',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 78,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 5,
                  ),
                ),
                const Text(
                  'N E B U L A   E D I T I O N',
                  style: TextStyle(
                    color: mint,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'CREATE BEYOND ORDINARY.',
                  style: TextStyle(
                    color: soft,
                    letterSpacing: 2,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: () =>
                        setState(() => started = true),
                    child: const Text(
                      'ENTER THE STUDIO  →',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      );

  Widget dashboardCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback tap, {
    bool highlighted = false,
  }) =>
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: glass(
            highlighted: highlighted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 29,
                color: mint,
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: dim,
                ),
              ),
            ],
          ),
        ),
      );

  Widget gallery() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'YOUR CREATIVE WORKSPACE',
            style: TextStyle(
              color: dim,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Studio.',
            style: TextStyle(
              fontSize: 34,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 19),
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: glass(
              highlighted: true,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: mint,
                  size: 50,
                ),
                const SizedBox(height: 12),
                const Text(
                  'CREATE YOUR SIGNATURE LOOK',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${signatures.length} signature filters · ${textureLabels.length} textures',
                  style: const TextStyle(
                    fontSize: 11,
                    color: dim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: dashboardCard(
                  Icons.add_photo_alternate_outlined,
                  'Import Photos',
                  'START A NEW EDIT',
                  importImages,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: dashboardCard(
                  Icons.layers_outlined,
                  'Explore Presets',
                  'CREATE YOUR OWN LOOK',
                  importImages,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Recent Projects',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          if (photos.isEmpty)
            Container(
              height: 100,
              decoration: glass(),
              alignment: Alignment.center,
              child: const Text(
                'Your next masterpiece starts here.',
                style: TextStyle(
                  color: dim,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => openImage(photos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    photos[i],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: glass(),
            child: const Row(
              children: [
                Icon(
                  Icons.bookmark_border,
                  color: mint,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Custom looks are saved on this device',
                    style: TextStyle(
                      color: soft,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget editor() => Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if ((comparing ? before : after) != null)
                    GestureDetector(
                      onLongPressStart: (_) =>
                          setState(
                        () => comparing = true,
                      ),
                      onLongPressEnd: (_) =>
                          setState(
                        () => comparing = false,
                      ),
                      child: InteractiveViewer(
                        minScale: .8,
                        maxScale: 5,
                        child: Image.memory(
                          (comparing ? before : after)!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  if (processing)
                    const Positioned(
                      top: 15,
                      right: 15,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  if (comparing)
                    const Positioned(
                      bottom: 10,
                      child: Text(
                        'ORIGINAL',
                        style: TextStyle(
                          color: mint,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: surface,
              border: Border(
                top: BorderSide(
                  color: Color(0xFF213438),
                ),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 61,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      7,
                      10,
                      7,
                    ),
                    children: [
                      for (final name in [
                        'Filters',
                        'Light',
                        'Color',
                        'Details',
                        'Texture',
                      ])
                        pill(
                          name,
                          section == name,
                          () => setState(
                            () => section = name,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 232,
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      5,
                      10,
                      7,
                    ),
                    child: tools(),
                  ),
                ),
                const Divider(
                  height: 1,
                  color: Color(0xFF25373B),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 5,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: processing
                              ? null
                              : () {
                                  setState(
                                    () => edits = Edits(),
                                  );
                                  refresh();
                                },
                          icon: const Icon(
                            Icons.restart_alt,
                          ),
                          label: const Text('Reset'),
                        ),
                        const Text(
                          'HOLD TO COMPARE',
                          style: TextStyle(
                            fontSize: 9,
                            color: dim,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: processing
                              ? null
                              : exportOptions,
                          icon: const Icon(
                            Icons.ios_share,
                          ),
                          label: const Text('Export'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!started) return welcome();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'L T J 3   E D I T O R',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          onPressed: () => setState(() {
            if (editorOpen) {
              editorOpen = false;
            } else {
              started = false;
            }
          }),
          icon: const Icon(
            Icons.arrow_back_ios_new,
          ),
        ),
        actions: [
          if (editorOpen)
            IconButton(
              onPressed: processing
                  ? null
                  : exportOptions,
              icon: const Icon(
                Icons.ios_share,
              ),
            ),
        ],
      ),
      body: editorOpen ? editor() : gallery(),
    );
  }
}
