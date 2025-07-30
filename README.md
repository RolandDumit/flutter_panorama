## Features

This package provides a simple way to create panoramic images from a series of photos taken with the camera. It supports both Android and iOS platforms and allows users to stitch images together to create a 360-degree panorama using OpenCV.
The images stitching process is done in a separate isolate to ensure smooth performance without blocking the UI thread.

The PanoramaCreator widget provides a full camera interface, including a start/stop button that begins an automatic photo-snapping process every 5°, and stops it to trigger the panorama generation.

## Getting started

To use this package, add `flutter_panorama` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  panorama_creator: ^1.2.0 # replace with the latest version
```

Run `flutter pub get` to install the package.

Then, import the package in your Dart code:

```dart
import 'package:flutter_panorama/flutter_panorama.dart';
```

# Platform specific configurations

**Make sure to correctly set up platform specific configurations for camerawesome to properly work.
Take a look at [camerawesome](https://pub.dev/packages/camerawesome) for more information.**

# Third party dependencies

To work, flutter_panorama uses the following dependencies:
- camerawesome
- sensors_plus
- opencv_dart
- path_provider

## Usage

```dart
class PanoramaPackageTest extends StatelessWidget {
  const PanoramaPackageTest({super.key});

  @override
  Widget build(BuildContext context) {
    return PanoramaCreator(
      displayStatus: true, // optional
      backgroundColor: Colors.black, // optional
      loadingWidget: const CircularProgressIndicator(), // optional
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Panorama error: $error')));
      },
      onSuccess: (panoramaPath) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => MyPanoramaViewer(file: File(panoramaPath))));
      },
      onAllPhotosSnapped: () {
        // Example usage: Use to hide the the panorama creator widget and show a loader while stitching process is ongoing.
        // IMPORTANT: Don't dispose of the widget while it's processing otherwise the [onSuccess] callback is never called.
        // Further instructions below. 
      },
      startWidget: const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
      stopWidget: const Icon(Icons.stop_circle_outlined, size: 70, color: Colors.white),
    );
  }
}
```

## IMPORTANT

When using the **onAllPhotosSnapped** callback to hide the panorama camera preview before the result is processed, wrap it with an Opacity widget, otherwise you'll dispose of the PanoramaCreator widget and the other callbacks will not get called.

When rotating to 360 degrees. The photo snapping process will automatically stop and panorama processing will start.