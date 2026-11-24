import 'dart:io';
import 'package:flutter/material.dart';

class ReceiptPhotoScreen extends StatelessWidget {
  final File file;
  const ReceiptPhotoScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (_, _, _) => const Text(
              'This photo could not be opened',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
