import 'package:opencv_dart/opencv.dart';

/// A utility class for stitching panoramas in an isolate.
/// Provides keys for parameters and return values.
class PanoramaIsolate {
  /// Parameters key for image paths
  static const String kImagePaths = 'imagePaths';

  /// Parameters key to return success status
  static const String kSuccess = 'success';

  /// Parameters key for error messages
  static const String kError = 'error';

  /// Parameters key for bytes of the stitched image
  static const String kBytes = 'bytes';

  /// Parameters key for return type of the stitched image
  static const String kReturnType = 'returnType';

  /// Possible return type for bytes of the stitched image
  static const String kReturnTypeBytes = 'bytes';

  /// Possible return type for file path of the stitched image
  static const String kReturnTypeFilePath = 'filePath';

  /// Parameters key for file path where the stitched image will be saved
  static const String kFilePath = 'filePath';

  /// Runs the panorama stitching in an isolate.
  /// Takes a map of parameters including image paths, return type, and file path.
  /// Returns a map with success status, error message, bytes of the stitched image, or file path.
  static Map<String, dynamic> stitchInIsolate(Map<String, dynamic> params) {
    final returnType = params[kReturnType] as String;
    final String filePath = params[kFilePath] as String;
    final List<String> imagePaths = params[kImagePaths] as List<String>;

    // Load images in isolate
    List<Mat> images = [];
    for (String path in imagePaths) {
      Mat img = imread(path);
      if (!img.isEmpty) {
        images.add(img);
      }
    }

    disposeImages() {
      for (var img in images) {
        img.dispose();
      }
    }

    if (images.length < 2) {
      disposeImages();
      return {kSuccess: false, kError: 'Not enough valid images'};
    }

    try {
      // Create stitcher and stitch
      Stitcher stitcher = Stitcher.create(mode: StitcherMode.PANORAMA);
      final (status, dst) = stitcher.stitch(images.cvd); // Use sync version in isolate
      disposeDst() {
        dst.dispose();
      }

      if (status != StitcherStatus.OK) {
        disposeImages();
        disposeDst();
        return {kSuccess: false, kError: 'Stitching failed with status: $status'};
      }

      // Handle return type
      if (returnType == kReturnTypeFilePath) {
        if (filePath.isEmpty) {
          disposeImages();
          disposeDst();
          return {kSuccess: false, kError: 'File path cannot be empty'};
        }

        // Save stitched image to file
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final saveFilePath = '$filePath/panorama_$timestamp.jpeg';
        final saveStatus = imwrite(saveFilePath, dst);
        if (!saveStatus) {
          disposeImages();
          disposeDst();
          return {kSuccess: false, kError: 'Failed to save stitched image to $saveFilePath'};
        }
        disposeImages();
        disposeDst();
        return {kSuccess: true, kFilePath: saveFilePath};
      }

      // Encode result to bytes for transfer
      final (encodeStatus, bytes) = imencode('.jpeg', dst);
      disposeImages();
      disposeDst();
      return {kSuccess: true, kBytes: bytes};
    } catch (e) {
      return {kSuccess: false, kError: e.toString()};
    }
  }
}
