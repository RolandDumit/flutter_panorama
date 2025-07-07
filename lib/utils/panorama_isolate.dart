import 'package:opencv_dart/opencv.dart';

class PanoramaIsolate {
  static const String kImagePaths = 'imagePaths';
  static const String kSuccess = 'success';
  static const String kError = 'error';
  static const String kBytes = 'bytes';
  static const String kReturnType = 'returnType';
  static const String kReturnTypeBytes = 'bytes';
  static const String kReturnTypeFilePath = 'filePath';
  static const String kFilePath = 'filePath';

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
        final saveStatus = imwrite(filePath, dst);
        if (!saveStatus) {
          disposeImages();
          disposeDst();
          return {kSuccess: false, kError: 'Failed to save stitched image to $filePath'};
        }
        disposeImages();
        disposeDst();
        return {kSuccess: true, kFilePath: filePath};
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
