import 'package:flutter/material.dart';
import 'package:flutter_panorama/flutter_panorama.dart';

class PanoramaExample extends StatelessWidget {
  const PanoramaExample({super.key});

  @override
  Widget build(BuildContext context) {
    return PanoramaCreator(
      saveDirectoryPath: 'path/to/save/directory', // Replace with your desired path
      displayStatus: true, // optional
      backgroundColor: Colors.black, // optional
      loadingWidget: const CircularProgressIndicator(), // optional
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Panorama error: $error')));
      },
      onSuccess: (panoramaPath) {
        /// Navigate to a viewer or display the panorama.
        /// [panoramaPath] is the path to the created panorama image.
      },
      startWidget: const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
      stopWidget: const Icon(Icons.stop_circle_outlined, size: 70, color: Colors.white),
      startText: 'Start Panorama',
      angleStatusText: 'Angle',
      photoCountStatusText: 'Stop Panorama',
    );
  }
}
