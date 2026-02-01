import 'dart:convert';
import 'dart:io';
// import 'dart:typed_data'; // unused
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Prendre une photo avec l'appareil photo et la compresser
  Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      
      if (photo == null) return null;
      
      return await _compressAndEncode(File(photo.path));
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  /// Choisir une image depuis la galerie et la compresser
  Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      
      if (image == null) return null;
      
      return await _compressAndEncode(File(image.path));
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Compresser l'image à 800x800 et encoder en base64
  Future<String?> _compressAndEncode(File file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Redimensionner à 800x800 max en gardant le ratio
      if (image.width > 800 || image.height > 800) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 800 : null,
          height: image.height >= image.width ? 800 : null,
        );
      }
      
      // Encoder en JPEG avec qualité 80%
      final compressedBytes = img.encodeJpg(image, quality: 80);
      
      // Convertir en base64 avec préfixe data URL
      final base64String = base64Encode(compressedBytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Afficher un dialog pour choisir la source de l'image
  Future<String?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(context);
                final result = await takePhoto();
                if (result != null) {
                  Navigator.of(context).pop(result);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.pop(context);
                final result = await pickFromGallery();
                if (result != null) {
                  Navigator.of(context).pop(result);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
