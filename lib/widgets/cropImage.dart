import 'dart:io';
import 'package:flutter/material.dart';
import 'package:custom_image_crop/custom_image_crop.dart';

class CropImage extends StatefulWidget {
  File image;
  CropImage({Key? key, required this.image }) : super(key: key);

  @override
  State<CropImage> createState() => _CropImageState();
}

class _CropImageState extends State<CropImage> {
  CustomImageCropController controller = CustomImageCropController();
  File? _image;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomImageCrop(
        backgroundColor: Colors.black,
        cropController: controller,
        image: FileImage(_image!),
        shape: CustomCropShape.Circle,
        cropPercentage: 0.8,
      ),
    );
  }
}
