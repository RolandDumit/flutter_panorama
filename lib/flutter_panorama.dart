import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_panorama/enums/panorama_return_type.dart';
import 'package:flutter_panorama/utils/panorama_isolate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A widget that allows users to create panoramas by capturing photos while rotating the device.
/// It uses the device's gyroscope to detect rotation and automatically captures photos at specific angle delta.
/// The captured photos are then stitched together to create a panorama image using OpenCV.
///
/// [minimumImageCount] is the minimum number of images required for panorama creation. If not provided defaults to 2.
/// [minimumImageErrorText] is the error message shown when the minimum image count is not met. If not provided defaults to "Need at least [minimumImageCount] photos for a panorama".
/// [returnType] sets how the panorama will be returned (as a file path or bytes). Defaults to [PanoramaReturnType.filePath].
/// [saveDirectoryPath] sets where the panorama images will be saved. If return type is [PanoramaReturnType.filePath], and [saveDirectoryPath] is null, it will default to [getApplicationDocumentsDirectory] from path_provider.
/// [onError] callback to handle errors, and optional widgets for start/stop actions and loading state.
/// [onSuccess] handles the panorama creation success case. Returns the panorama file path if [returnType] is [PanoramaReturnType.filePath], or a Uint8List if [returnType] is [PanoramaReturnType.bytes].
/// [onAllPhotosSnapped] callback function called when all photos are snapped. It can be used to handle at will the ui after photos are snapped. e.g. pop the camera ui after all photos are snapped and wait for the success callback to be called.
/// [startWidget] and [stopWidget] can be customized to change the appearance of the start/stop buttons. They fallback to basic play/stop icons if not provided.
/// [displayStatus] controls whether to show the current angle and photo count status.
/// [loaderColor] controls the default loader color.
/// [loadingText] sets the text shown during panorama creation.
/// [loadingWidget] overrides the default loader widget while panorama is being processed.
/// [backgroundColor] sets the background color of the widget, defaulting to black.
/// [angleStatusText] and [photoCountStatusText] allow customization of the status text labels while panorama is being captured, defaulting to "Angle" and "Photos" respectively.
/// [startText] is the text displayed on the start button when panorama is not active, defaulting to "Press start to begin panorama".
///
/// Example usage:
/// ```dart
/// PanoramaCreator(
///   returnType: PanoramaReturnType.filePath, // or PanoramaReturnType.bytes
///   saveDirectoryPath: getApplicationDocumentsDirectory(),
///   displayStatus: true, // optional
///   backgroundColor: Colors.black, // optional
///   loadingWidget: const CircularProgressIndicator(), // optional
///   loadingText: 'Loading...' // optional, defaults to 'Creating panorama'
///   loaderColor: Colors.white // optional
///   onError: (error) {
///     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Panorama error: $error')));
///   },
///   onSuccess: (panoramaPath) {
///     Navigator.of(context).push(MaterialPageRoute(builder: (context) => PanoramaViewer(file: File(panoramaPath))));
///   },
///   onAllPhotosSnapped: () {
///     Navigator.of(context).pop();
///   }
///   startWidget: const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
///   stopWidget: const Icon(Icons.stop_circle_outlined, size: 70, color: Colors.white),
///   startText: 'Press start to begin panorama', // optional
///   angleStatusText: 'Angle', // optional
///   photoCountStatusText: 'Photos', // optional
/// );
/// ```
///
class PanoramaCreator extends StatefulWidget {
  /// The minimum number of images required for panorama creation.
  /// If not provided, it defaults to 2.
  final int minimumImageCount;

  /// The error message shown when the minimum image count is not met.
  /// If not provided, it defaults to "Need at least [minimumImageCount] photos for a panorama".
  final String? minimumImageErrorText;

  /// The return type for the panorama creation process.
  /// It defines how the PanoramaCreator will return the panorama image.
  /// If not provided, it defaults to [PanoramaReturnType.filePath].
  final PanoramaReturnType returnType;

  /// Path to the directory where the panorama images will be saved.
  final String? saveDirectoryPath;

  /// Callback function that is called when an error occurs during panorama creation.
  final Function(String errorMessage)? onError;

  /// Callback function that is called when the panorama is successfully created.
  final Function(dynamic) onSuccess;

  /// Callback function that is called when all photos are snapped.
  /// It can be used to handle at will the ui after photos are snapped. e.g. pop the camera ui after all photos are snapped and wait for the success callback to be called.
  final VoidCallback? onAllPhotosSnapped;

  /// Start panorama button widget.
  /// Fallbacks to a play icon if not provided.
  final Widget? startWidget;

  /// Stop panorama button widget.
  /// Fallbacks to a stop icon if not provided.
  final Widget? stopWidget;

  /// Widget displayed while the panorama is being processed and while the camera is being initialized.
  final Widget? loadingWidget;

  /// Whether to display the current angle and photo count status.
  final bool displayStatus;

  /// Background color of the panorama creator widget, displayed behind the camera preview and buttons.
  final Color backgroundColor;

  /// Progress indicator color.
  final Color loaderColor;

  /// The text displayed during loading phase, while the panorama is created.
  /// If not provided, the label will default to english "Creating panorama".
  final String? loadingText;

  /// The angle status text, displayed in the status area if [displayStatus] is true.
  /// If not provided, the label will default to english "Angle".
  final String? angleStatusText;

  /// The photo count status text, displayed in the status area if [displayStatus] is true.
  /// If not provided, the label will default to english "Photos".
  final String? photoCountStatusText;

  /// The text displayed on the start button, displayed in the status area if [displayStatus] is true.
  /// If not provided, the label will default to english "Press start to begin panorama".
  final String? startText;

  /// Creates a PanoramaCreator widget that allows users to capture and stitch photos into a panorama.
  const PanoramaCreator({
    super.key,
    this.minimumImageCount = 2,
    this.minimumImageErrorText,
    this.returnType = PanoramaReturnType.filePath,
    this.saveDirectoryPath,
    required this.onSuccess,
    this.onAllPhotosSnapped,
    this.onError,
    this.startWidget,
    this.stopWidget,
    this.loadingWidget,
    this.displayStatus = false,
    this.backgroundColor = Colors.black,
    this.loaderColor = Colors.white,
    this.loadingText,
    this.angleStatusText,
    this.photoCountStatusText,
    this.startText,
  });

  @override
  State<PanoramaCreator> createState() => _PanoramaCreatorState();
}

class _PanoramaCreatorState extends State<PanoramaCreator> with WidgetsBindingObserver {
  // CameraController? controller;
  PhotoCameraState? photoState;

  // Variables for rotation tracking
  double _currentZAngle = 0.0;
  double _lastPhotoZAngle = 0.0;
  final double _angleDeltaThreshold = 5.0; // Take photo every 15 degrees
  bool _takingPhoto = false;
  bool _isPanoramaActive = false;
  bool _isProcessing = false;
  final List<XFile> _capturedPhotos = List<XFile>.empty(growable: true);
  bool _showMinimumImagesError = false;

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  DateTime? _lastGyroEventTime;

  _startPanorama() {
    _capturedPhotos.clear();
    _currentZAngle = 0.0;
    _lastPhotoZAngle = 0.0;
    _lastGyroEventTime = null;
    setState(() {
      _isPanoramaActive = true;
    });

    // Take the first photo immediately
    _takePhoto();

    // Set up gyroscope listener for rotation detection
    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      if (!_isPanoramaActive) return;

      final now = DateTime.now();
      if (_lastGyroEventTime != null) {
        final duration = now.difference(_lastGyroEventTime!);
        final seconds = duration.inMicroseconds / 1000000.0;

        // Convert rotation rate to angle change
        final yRotationDelta = event.y * seconds * (180.0 / pi);
        _currentZAngle += yRotationDelta;

        if (_currentZAngle.abs() >= 350 && context.mounted) {
          _stopPanorama(context);
          return;
        }

        // Check if we've rotated enough since last photo
        double angleDelta = (_currentZAngle - _lastPhotoZAngle).abs();
        if (angleDelta >= _angleDeltaThreshold && !_takingPhoto && photoState?.captureMode == CaptureMode.photo) {
          _takePhoto();
          _lastPhotoZAngle = _currentZAngle;
        }

        setState(() {});
      }
      _lastGyroEventTime = now;
    });
  }

  _stopPanorama(BuildContext context) async {
    widget.onAllPhotosSnapped?.call();

    if (_capturedPhotos.length < widget.minimumImageCount) {
      setState(() {
        _showMinimumImagesError = true;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isPanoramaActive = false;
      });
    }
    _gyroscopeSubscription?.cancel();

    if (_capturedPhotos.length < 2) {
      widget.onError?.call('Need at least 2 photos for a panorama');
      setState(() {});
      return;
    }

    // Show loading indicator
    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      dynamic result;

      final imagePaths = _capturedPhotos.map((photo) => photo.path).toList();
      String saveFilePath = widget.saveDirectoryPath != null && widget.saveDirectoryPath!.isNotEmpty
          ? widget.saveDirectoryPath!
          : (await getApplicationDocumentsDirectory()).path;
      saveFilePath = saveFilePath.characters.last == '/'
          ? saveFilePath.substring(0, widget.saveDirectoryPath!.length - 1)
          : saveFilePath;

      final isolateResult = await compute(PanoramaIsolate.stitchInIsolate, {
        PanoramaIsolate.kReturnType: widget.returnType == PanoramaReturnType.bytes
            ? PanoramaIsolate.kReturnTypeBytes
            : PanoramaIsolate.kReturnTypeFilePath,
        PanoramaIsolate.kFilePath: saveFilePath,
        PanoramaIsolate.kImagePaths: imagePaths,
      });

      if (!(isolateResult['success'] as bool)) {
        widget.onError?.call('Panorama stitching failed: ${isolateResult['error']}');
        return;
      }

      // Check the return type and get the result
      if (widget.returnType == PanoramaReturnType.filePath) {
        result = isolateResult[PanoramaIsolate.kFilePath] as String;
      } else {
        result = isolateResult[PanoramaIsolate.kBytes] as Uint8List;
      }

      if (mounted) {
        widget.onSuccess(result);
      }
    } catch (e) {
      widget.onError?.call('Failed to create panorama: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  _takePhoto() async {
    if (_takingPhoto || photoState == null) return;

    _takingPhoto = true;
    try {
      photoState!.takePhoto(
          onPhoto: (captureRequest) => captureRequest.when(single: (captureRequest) {
                if (mounted) {
                  setState(() {
                    if (captureRequest.file != null) {
                      _capturedPhotos.add(captureRequest.file!);
                    }
                  });
                }
              }));
      if (mounted && _capturedPhotos.length >= widget.minimumImageCount) {
        setState(() {
          _showMinimumImagesError = false;
        });
      }
    } catch (e) {
      widget.onError?.call('Error taking photo: ${e.toString()}');
    } finally {
      _takingPhoto = false;
    }
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    photoState?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CameraAwesomeBuilder.custom(
              saveConfig: SaveConfig.photo(),
              sensorConfig: SensorConfig.single(sensor: Sensor.type(SensorType.wideAngle)),
              previewFit: CameraPreviewFit.cover,
              onMediaCaptureEvent: (capture) {},
              builder: (CameraState state, AnalysisPreview preview) {
                state.when(
                  onPreparingCamera: (state) {
                    return Center(
                        child: widget.loadingWidget ?? SpinKitThreeBounce(color: widget.loaderColor, size: 30));
                  },
                  onPhotoMode: (state) {
                    photoState = state;
                  },
                );

                return Column(
                  spacing: 8,
                  children: [
                    if (_showMinimumImagesError)
                      Padding(
                        padding: EdgeInsets.only(top: 16 + MediaQuery.viewPaddingOf(context).top),
                        child: textContainer(widget.minimumImageErrorText ??
                            'Need at least ${widget.minimumImageCount} photos for a panorama'),
                      ),

                    Spacer(),

                    // Status display
                    if (widget.displayStatus)
                      Center(
                        child: textContainer(
                          _isProcessing
                              ? widget.loadingText ?? 'Creating panorama'
                              : _isPanoramaActive
                                  ? '${widget.angleStatusText ?? 'Angle'} ${_currentZAngle.toStringAsFixed(1)}°\n${widget.photoCountStatusText ?? 'Photos'} ${_capturedPhotos.length}'
                                  : widget.startText ?? 'Press start to begin panorama',
                        ),
                      ),
                    // Start/Stop button
                    Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                      child: GestureDetector(
                        onTap: () => _isProcessing
                            ? null
                            : _isPanoramaActive
                                ? _stopPanorama(context)
                                : _startPanorama(),
                        child: _isProcessing
                            ? widget.loadingWidget ?? SpinKitThreeBounce(color: widget.loaderColor, size: 30)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: ShapeDecoration(
                                        shape: CircleBorder(), color: Colors.black.withAlpha((.1 * 255).toInt())),
                                    child: Center(
                                      child: AnimatedCrossFade(
                                        firstChild: widget.stopWidget ??
                                            const Icon(Icons.stop_circle_rounded, size: 80, color: Colors.white),
                                        secondChild: widget.startWidget ??
                                            const Icon(Icons.play_circle_fill_rounded, size: 80, color: Colors.white),
                                        crossFadeState:
                                            _isPanoramaActive ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                        duration: const Duration(milliseconds: 200),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget textContainer(String text) => ClipRSuperellipse(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: ShapeDecoration(
              color: Colors.black.withAlpha((.2 * 255).toInt()),
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
