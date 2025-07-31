import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}


class _AddPostPageState extends State<AddPostPage> {
  File? _imageFile;
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _postIssue() async {
    if (_imageFile == null || _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo and enter a caption.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      String fileName = 'issues/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      print('Uploading to: $fileName');
      UploadTask uploadTask = ref.putFile(_imageFile!);
      TaskSnapshot snapshot;
      try {
        snapshot = await uploadTask;
        print('Upload complete.');
      } catch (e) {
        print('Upload failed: $e');
        throw Exception('Image upload failed: $e');
      }
      if (snapshot.state != TaskState.success) {
        print('Upload not successful. State: \\${snapshot.state}');
        throw Exception('Image upload was not successful.');
      }
      String imageUrl;
      try {
        imageUrl = await snapshot.ref.getDownloadURL();
        print('Download URL: $imageUrl');
      } catch (e) {
        print('Failed to get download URL: $e');
        throw Exception('Failed to get download URL: $e');
      }

      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) throw Exception('Location service not enabled');
      }
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) throw Exception('Location permission denied');
      }
      LocationData locationData = await location.getLocation();

      await FirebaseFirestore.instance.collection('issues').add({
        'caption': _captionController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Unresolved', // Changed from 'Unprocessed' to 'Unresolved'
        'location': {
          'lat': locationData.latitude,
          'long': locationData.longitude,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue posted successfully!')),
      );
      setState(() {
        _imageFile = null;
        _captionController.clear();
      });
    } catch (e, stack) {
      print('Error in _postIssue: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[700]!),
                image: _imageFile != null
                    ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                    : null,
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Tap to take a photo',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _captionController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.deepPurpleAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _postIssue,
                  child: const Text(
                    'Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }
}
