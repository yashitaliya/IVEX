import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../config/appwrite_config.dart';

/// Singleton service for Appwrite client and services
class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;

  late final Storage _storage;
  late final Databases _databases;
  late final Realtime _realtime;

  bool _isInitialized = false;

  AppwriteService._internal();

  /// Initialize the Appwrite services using the global client
  void init() {
    if (_isInitialized) return;

    _storage = Storage(client);
    _databases = Databases(client);
    _realtime = Realtime(client);

    _isInitialized = true;
  }

  // Getters for services
  Client get appwriteClient => client;
  Storage get storage => _storage;
  Databases get databases => _databases;
  Realtime get realtime => _realtime;

  /// Send a ping to verify connection
  Future<void> sendPing() async {
    await client.ping();
  }

  /// Upload image to storage bucket
  /// Returns the file ID of the uploaded image
  Future<String> uploadImage(List<int> bytes, String fileName) async {
    final file = await _storage.createFile(
      bucketId: AppwriteConfig.bucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: fileName),
    );
    return file.$id;
  }

  /// Subscribe to realtime updates for a specific file's results
  /// Returns a stream that emits when the result document is created/updated
  RealtimeSubscription subscribeToResults(String fileId) {
    return _realtime.subscribe([AppwriteConfig.resultsChannel]);
  }

  /// Get all results for display
  Future<List<Document>> getResults() async {
    final response = await _databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.resultsCollectionId,
      queries: [Query.orderDesc('\$createdAt'), Query.limit(20)],
    );
    return response.documents;
  }

  /// Get a specific result by document ID
  Future<Document> getResult(String documentId) async {
    return await _databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.resultsCollectionId,
      documentId: documentId,
    );
  }

  /// Get file preview URL
  String getFilePreviewUrl(String fileId) {
    return AppwriteConfig.getFilePreviewUrl(fileId);
  }
}
