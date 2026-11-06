# Luna Pro — Flutter starter

A real Flutter project starter for iOS and Android. Features: gallery import, zoomable photo preview, brightness/contrast/saturation adjustments, reset, full-resolution JPEG export through system share sheet. Editing is local and offline. UI is currently in English.

## Setup
1. Install Flutter SDK and Android Studio (and Xcode on macOS for iOS).
2. Run `flutter create luna_pro` in an empty workspace.
3. Replace generated `pubspec.yaml` and `lib/main.dart` with the files in this archive.
4. Run `flutter pub get` and `flutter run`.

On iOS, add `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist` explaining photo selection. Follow current image_picker and share_plus platform setup notes.

## Limitations
This is milestone 1, not a finished editor. It has no layers, masking, AI tools, undo history, cropping, or non-destructive project persistence. Processing is synchronous and can stall on very large images; next milestone should move image processing to an isolate, use tiled previews, and introduce an edit-operation model. JPEG export does not preserve transparency or all metadata. No cloud or paid API is used.
