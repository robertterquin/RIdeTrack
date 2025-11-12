import 'package:flutter/material.dart';
import 'package:bikeapp/core/services/cloudinary_service.dart';

class CloudinaryUploadButton extends StatelessWidget {
  const CloudinaryUploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        CloudinaryService().uploadImage();
      },
      child: const Text("Upload Image"),
    );
  }
}
