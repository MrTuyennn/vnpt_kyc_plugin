import 'dart:io';
import 'dart:convert';

import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:path/path.dart' as p;

class EkycSessionArtifacts {
  EkycSessionArtifacts(this.rootDir);

  final Directory rootDir;

  String get frontFull => p.join(rootDir.path, 'front.jpg');
  String get backFull => p.join(rootDir.path, 'back.jpg');
  String get frontCrop => p.join(rootDir.path, 'front_crop.jpg');
  String get backCrop => p.join(rootDir.path, 'back_crop.jpg');
  String get farPreview =>
      p.join(rootDir.path, '${EkycArtifactNames.farPreview}.jpg');
  String get farCrop =>
      p.join(rootDir.path, '${EkycArtifactNames.farCrop}.jpg');
  String get nearPreview =>
      p.join(rootDir.path, '${EkycArtifactNames.nearPreview}.jpg');
  String get nearCrop =>
      p.join(rootDir.path, '${EkycArtifactNames.nearCrop}.jpg');
  String get scan3d => p.join(rootDir.path, EkycArtifactNames.scan3dFile);
  String get faceLog => p.join(rootDir.path, 'face_log.txt');

  String cropParamFront = '';
  String cropParamBack = '';
  String ocrToken = EkycArtifactNames.defaultOcrTokenNoWatermark;

  Future<void> ensureDir() async {
    if (!await rootDir.exists()) await rootDir.create(recursive: true);
  }

  Future<void> saveMetadata() async {
    await File(p.join(rootDir.path, 'session.json')).writeAsString(
        jsonEncode({
          'cropParamFront': cropParamFront,
          'cropParamBack': cropParamBack,
        }),
        flush: true);
  }

  Future<void> loadMetadata() async {
    final file = File(p.join(rootDir.path, 'session.json'));
    if (!await file.exists()) return;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    cropParamFront = data['cropParamFront'] as String? ?? '';
    cropParamBack = data['cropParamBack'] as String? ?? '';
  }

  FullIdentityArtifactPaths toPaths() => FullIdentityArtifactPaths(
        frontFullPath: frontFull,
        backFullPath: backFull,
        frontCropPath: frontCrop,
        backCropPath: backCrop,
        cropParamFront: cropParamFront,
        cropParamBack: cropParamBack,
        farPreviewPath: farPreview,
        farCropPath: farCrop,
        nearPreviewPath: nearPreview,
        nearCropPath: nearCrop,
        scan3dPath: scan3d,
        faceLogPath: faceLog,
      );
}
