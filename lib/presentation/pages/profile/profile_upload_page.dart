import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class ProfileUploadPage extends StatefulWidget {
  const ProfileUploadPage({super.key});

  @override
  State<ProfileUploadPage> createState() => _ProfileUploadPageState();
}

class _ProfileUploadPageState extends State<ProfileUploadPage> {
  File? _selectedFile;
  bool _isUploading = false;

  // Your actual Cloudinary credentials
  final String cloudName = "dlkeeyrts";
  final String uploadPreset = "RideTrack";

  PlatformFile? _selectedPlatformFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _selectedPlatformFile = result.files.single;
        if (!kIsWeb && result.files.single.path != null) {
          _selectedFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _uploadToCloudinary() async {
    if (_selectedPlatformFile == null) return;

    setState(() => _isUploading = true);

    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      // Handle web vs mobile differently
      if (kIsWeb) {
        // For web: use bytes
        final bytes = _selectedPlatformFile!.bytes;
        if (bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: _selectedPlatformFile!.name,
          ));
        }
      } else {
        // For mobile/desktop: use file path
        if (_selectedFile != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path,
          ));
        }
      }

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        final imageUrl = data['secure_url'];
        print("✅ Upload successful!");
        print("Profile Image URL: $imageUrl");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Image Uploaded!")),
          );
        }

        // TODO: Save imageUrl to Firebase user profile if needed
      } else {
        print("❌ Upload failed: ${response.statusCode}");
        print("Response: $resBody");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      print("❌ Error uploading: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Profile Image")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedPlatformFile != null)
              CircleAvatar(
                radius: 80,
                backgroundImage: kIsWeb
                    ? MemoryImage(_selectedPlatformFile!.bytes!)
                    : FileImage(_selectedFile!) as ImageProvider,
              )
            else
              CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.person, size: 80, color: Colors.white70),
              ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text("Select Image from Files"),
            ),
            const SizedBox(height: 15),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _uploadToCloudinary,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload to Cloudinary"),
                  ),
          ],
        ),
      ),
    );
  }
}
