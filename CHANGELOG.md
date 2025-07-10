## 1.0.2

MAJOR BUG fixed where the panorama stitching fails when selecting filePath as returnType.

## 1.0.1

* Panorama stitching now happens in a separate isolate for improved performance.
* Ne wloading indicator when panorama is processing.
* You can now choose the return type: filePath or bytes (Uint8List).
* onSuccess returns a String path or Uint8List based on returnType.
* Added save directory path parameter to customize where the panorama is saved if returnType is filePath.
* Handled lifecycle changes.
* Correctly handled subscriptions.
* Corrected camera preview UI to adapt to all screen sizes.

## 0.0.4

Added the possibility to customize the UI labels.

## 0.0.3

Created an example and wrote better single API documentation.

## 0.0.2

Added better documentation and examples for the panorama_creator package.

## 0.0.1

Initial release of the panorama_creator package.
Provides a basic interface for creating panoramic images from a series of photos taken with the camera.
