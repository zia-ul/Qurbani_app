import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_client.dart';

class UploadedFileInfo {
const UploadedFileInfo({
required this.url,
this.publicId,
this.resourceType,
this.originalName,
this.mimeType,
this.sizeBytes,
});

final String url;
final String? publicId;
final String? resourceType;
final String? originalName;
final String? mimeType;
final int? sizeBytes;

factory UploadedFileInfo.fromJson(Map<String, dynamic> json) {
return UploadedFileInfo(
url: (json['url'] ?? json['secure_url']).toString(),
publicId: json['public_id']?.toString(),
resourceType: json['resource_type']?.toString(),
originalName: json['original_name']?.toString(),
mimeType: json['mime_type']?.toString(),
sizeBytes: json['size_bytes'] is int
? json['size_bytes'] as int
: int.tryParse(json['size_bytes']?.toString() ?? ''),
);
}
}

class UploadService {
UploadService._();

static const _storage = FlutterSecureStorage();

// Increased timeout for mobile uploads / slow networks
static const _timeout = Duration(seconds: 120);

static Future<List<UploadedFileInfo>> uploadFiles(
List<String> filePaths, {
String context = 'general',
bool saveProfilePhoto = false,
}) async {
if (filePaths.isEmpty) {
return const [];
}


final token = await _storage.read(key: 'token');

if (token == null || token.isEmpty) {
  throw const ApiException('Not authenticated');
}

final request = http.MultipartRequest(
  'POST',
  ApiClient.uri('uploads'),
)
  ..headers['Authorization'] = 'Bearer $token'
  ..fields['context'] = context;

if (saveProfilePhoto) {
  request.fields['saveProfilePhoto'] = 'true';
}

for (final path in filePaths) {
  final file = File(path);

  // Validate file exists
  if (!await file.exists()) {
    throw ApiException(
      'Selected file no longer exists: $path',
    );
  }

  // Detect MIME type safely
  final mimeType =
      lookupMimeType(path) ?? 'image/jpeg';

  final mimeParts = mimeType.split('/');

  if (mimeParts.length != 2) {
    throw ApiException(
      'Unable to determine file type for upload',
    );
  }

  // Debug logging
  print('Uploading file: $path');
  print('Detected MIME: $mimeType');

  request.files.add(
    await http.MultipartFile.fromPath(
      'files',
      path,
      contentType: MediaType(
        mimeParts[0],
        mimeParts[1],
      ),
    ),
  );
}

try {
  final streamedResponse =
      await request.send().timeout(_timeout);

  final response =
      await http.Response.fromStream(streamedResponse);

  final responseBody = response.body;

  print('Upload response status: ${response.statusCode}');
  print('Upload response body: $responseBody');

  if (response.statusCode != 201) {
    throw ApiException(
      ApiClient.errorMessage(
        response,
        fallbackMessage:
            'Unable to upload files right now.',
      ),
      statusCode: response.statusCode,
    );
  }

  final decoded = jsonDecode(responseBody);

  if (decoded is! Map<String, dynamic>) {
    throw const ApiException(
      ApiClient.invalidResponseMessage,
    );
  }

  final files = decoded['files'];

  if (files is List) {
    return files
        .map(
          (file) => UploadedFileInfo.fromJson(
            Map<String, dynamic>.from(file as Map),
          ),
        )
        .toList();
  }

  // Backward compatibility
  final urls = decoded['urls'];

  if (urls is List) {
    return urls
        .map(
          (url) => UploadedFileInfo(
            url: url.toString(),
          ),
        )
        .toList();
  }

  throw const ApiException(
    ApiClient.invalidResponseMessage,
  );
} on TimeoutException {
  throw const ApiException(
    'Upload timed out. Please try again.',
  );
} on SocketException {
  throw const ApiException(
    'No internet connection available.',
  );
} on http.ClientException catch (error) {
  if (ApiClient.isConnectivityIssue(error.message)) {
    throw const ApiException(
      ApiClient.offlineMessage,
    );
  }

  throw ApiException(
    'Upload failed: ${error.message}',
  );
} catch (error) {
  if (error is ApiException) {
    rethrow;
  }

  throw ApiException(
    'Unexpected upload error: $error',
  );
}


}

static Future<String> uploadFile(
String filePath, {
String context = 'general',
bool saveProfilePhoto = false,
}) async {
final files = await uploadFiles(
[filePath],
context: context,
saveProfilePhoto: saveProfilePhoto,
);


if (files.isEmpty) {
  throw const ApiException(
    'No uploaded file URL was returned',
  );
}

return files.first.url;


}
}
