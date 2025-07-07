import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_panorama/enums/panorama_return_type.dart';
import 'package:opencv_dart/opencv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A widget that allows users to create panoramas by capturing photos while rotating the device.
/// It uses the device's gyroscope to detect rotation and automatically captures photos at specific angle delta.
/// The captured photos are then stitched together to create a panorama image using OpenCV.
///
/// [returnType] to specify how the panorama will be returned (as a file path or bytes). Defaults to [PanoramaReturnType.filePath].
/// [saveDirectoryPath] specifies where the panorama images will be saved. If return type is [PanoramaReturnType.filePath], and [saveDirectoryPath] is null, it will default to [getApplicationDocumentsDirectory] from path_provider.
/// [onError] callback to handle errors, and optional widgets for start/stop actions and loading state.
/// [onSuccess] handles the panorama creation success case. Returns the panorama file path if [returnType] is [PanoramaReturnType.filePath], or a Uint8List if [returnType] is [PanoramaReturnType.bytes].
/// [startWidget] and [stopWidget] can be customized to change the appearance of the start/stop buttons. They fallback to basic play/stop icons if not provided.
/// [loadingWidget] is displayed while the panorama is being processed. Fallbacks to [CircularProgressIndicator] if not provided.
/// [displayStatus] controls whether to show the current angle and photo count status.
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
///   onError: (error) {
///     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Panorama error: $error')));
///   },
///   onSuccess: (panoramaPath) {
///     Navigator.of(context).push(MaterialPageRoute(builder: (context) => PanoramaViewer(file: File(panoramaPath))));
///   },
///   startWidget: const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
///   stopWidget: const Icon(Icons.stop_circle_outlined, size: 70, color: Colors.white),
///   startText: 'Press start to begin panorama', // optional
///   angleStatusText: 'Angle', // optional
///   photoCountStatusText: 'Photos', // optional
/// );
/// ```
///
class PanoramaCreator extends StatefulWidget {
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
    this.returnType = PanoramaReturnType.filePath,
    this.saveDirectoryPath,
    required this.onSuccess,
    this.onError,
    this.startWidget,
    this.stopWidget,
    this.loadingWidget,
    this.displayStatus = false,
    this.backgroundColor = Colors.black,
    this.angleStatusText,
    this.photoCountStatusText,
    this.startText,
  }) : assert(
          returnType != PanoramaReturnType.filePath || (saveDirectoryPath != null && saveDirectoryPath != ''),
          'When using PanoramaReturnType.filePath, saveDirectoryPath must be provided and not empty.',
        );

  @override
  State<PanoramaCreator> createState() => _PanoramaCreatorState();
}

class _PanoramaCreatorState extends State<PanoramaCreator> with WidgetsBindingObserver {
  CameraController? controller;

  // Variables for rotation tracking
  double _currentZAngle = 0.0;
  double _lastPhotoZAngle = 0.0;
  final double _angleDeltaThreshold = 15.0; // Take photo every 15 degrees
  bool _takingPhoto = false;
  bool _isPanoramaActive = false;
  bool _isProcessing = false;
  bool _isInitializingCamera = false;
  final List<XFile> _capturedPhotos = List<XFile>.empty(growable: true);

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  DateTime? _lastGyroEventTime;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      debugPrint('Camera not initialized, skipping lifecycle handling');
      return;
    }

    if (state == AppLifecycleState.inactive) {
      debugPrint('AppLifecycleState.inactive: Pausing camera');
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('AppLifecycleState.resumed: Reinitializing camera');
      _initController(cameraDescription: cameraController.description);
    }
  }

  Future<void> _initController({CameraDescription? cameraDescription}) async {
    if (mounted) {
      setState(() {
        _isInitializingCamera = true;
        _isProcessing = false;
      });
    }

    final cameras = await availableCameras();

    if (cameras.isNotEmpty) {
      controller = CameraController(
        cameraDescription ?? cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller?.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((Object e) {
        if (e is CameraException) {
          switch (e.code) {
            case 'CameraAccessDenied':
              widget.onError?.call('Panorama error: Camera access denied');
              break;
            default:
              widget.onError?.call('Panorama error: ${e.description}');
              break;
          }
        }
      });
    } else {
      widget.onError?.call('No cameras found');
    }

    if (mounted) {
      setState(() {
        _isInitializingCamera = false;
      });
    }
  }

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

        // Check if we've rotated enough since last photo
        double angleDelta = (_currentZAngle - _lastPhotoZAngle).abs();
        if (angleDelta >= _angleDeltaThreshold && !_takingPhoto && (controller?.value.isInitialized ?? false)) {
          _takePhoto();
          _lastPhotoZAngle = _currentZAngle;
        }

        setState(() {});
      }
      _lastGyroEventTime = now;
    });
  }

  _stopPanorama(BuildContext context) async {
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

      // Load the images using OpenCV
      List<Mat> images = [];
      for (XFile photo in _capturedPhotos) {
        Mat img = imread(photo.path);
        if (img.isEmpty) {
          widget.onError?.call('Failed to load image: ${photo.path}');
          continue;
        }
        images.add(img);
      }

      if (images.length < 2) {
        widget.onError?.call('Not enough valid images to create a panorama');
      }

      // Create a stitcher and stitch the images
      Stitcher stitcher = Stitcher.create(mode: StitcherMode.PANORAMA);
      final estimateResult = stitcher.estimateTransform(images.cvd);
      if (estimateResult != StitcherStatus.OK) {
        widget.onError?.call('Failed to estimate transform: $estimateResult');
        return;
      }

      final (status, dst) = await stitcher.stitchAsync(images.cvd);

      if (status != StitcherStatus.OK) {
        widget.onError?.call('Panorama stitching failed with status: $status');
      }

      // If return type is file path
      if (widget.returnType == PanoramaReturnType.filePath) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        final directoryPath = widget.saveDirectoryPath == null
            ? getApplicationDocumentsDirectory()
            : widget.saveDirectoryPath!.characters.last == '/'
                ? widget.saveDirectoryPath!.substring(0, widget.saveDirectoryPath!.length - 1)
                : widget.saveDirectoryPath;

        final panoramaPath = '$directoryPath/panorama_$timestamp.jpg';

        // Save the result
        imwrite(panoramaPath, dst);
      } else {
        // If return type is bytes
        final panoramaBytes = imencode('.jpeg', dst);
        result = panoramaBytes;
      }

      // Clean up OpenCV resources
      for (var img in images) {
        img.dispose();
      }
      dst.dispose();

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
    if (_takingPhoto || controller == null) return;

    _takingPhoto = true;
    try {
      final XFile photo = await controller!.takePicture();
      if (mounted) {
        setState(() {
          _capturedPhotos.add(photo);
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
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing || _isInitializingCamera || controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: _isProcessing || controller == null
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                spacing: 8,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      width: double.infinity,
                      child: CameraPreview(controller!),
                    ),
                  ),

                  // Start button
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: [
                        if (widget.displayStatus)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                _isPanoramaActive
                                    ? '${widget.angleStatusText ?? 'Angle'} ${_currentZAngle.toStringAsFixed(1)}°\n${widget.photoCountStatusText ?? 'Photos'} ${_capturedPhotos.length}'
                                    : widget.startText ?? 'Press start to begin panorama',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FittedBox(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                              child: GestureDetector(
                                onTap: () => _isPanoramaActive ? _stopPanorama(context) : _startPanorama(),
                                child: _isPanoramaActive
                                    ? widget.stopWidget ??
                                        const Icon(Icons.stop_circle_outlined, size: 70, color: Colors.white)
                                    : widget.startWidget ??
                                        const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
