import 'package:appwrite/appwrite.dart';

/// Global Appwrite client with hardcoded project details
final Client client = Client()
    .setProject("ivex")
    .setEndpoint("https://fra.cloud.appwrite.io/v1");

/// IVEX Appwrite Configuration
class AppwriteConfig {
  // Appwrite Server Configuration
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';

  // Appwrite Project ID
  static const String projectId = 'ivex';

  // Storage Bucket ID for user selfies
  static const String bucketId = 'photos';

  // Database Configuration
  static const String databaseId = 'ivex_db';
  static const String resultsCollectionId = 'results';

  // Realtime channels
  static String get resultsChannel =>
      'databases.$databaseId.collections.$resultsCollectionId.documents';

  // Storage file preview URL helper
  static String getFilePreviewUrl(String fileId) {
    return '$endpoint/storage/buckets/$bucketId/files/$fileId/preview?project=$projectId';
  }

  // Storage file view URL helper
  static String getFileViewUrl(String fileId) {
    return '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
  }

  // Auth redirects (must also be added in Appwrite platform settings)
  static const String authSuccessUrl = 'appwrite-callback-ivex';
  static const String authFailureUrl = 'appwrite-callback-ivex';
  static const String emailVerificationRedirectUrl =
      'https://ivex.app/email-verified';
  static const String passwordRecoveryRedirectUrl =
      'https://ivex.app/reset-password';
}
