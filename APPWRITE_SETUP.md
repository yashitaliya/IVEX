# IVEX - Appwrite Setup Guide

This guide walks you through setting up Appwrite for the IVEX hairstyle consulting app.

## Prerequisites

- [Appwrite Console](https://cloud.appwrite.io) account (or self-hosted instance)
- [Google AI Studio](https://aistudio.google.com/apikey) API key for Gemini
- [OpenRouter](https://openrouter.ai/keys) API key for image generation

---

## Step 1: Create Appwrite Project

1. Log into [Appwrite Console](https://cloud.appwrite.io)
2. Click **"Create Project"**
3. Name it `IVEX` and note down the **Project ID**
4. Go to **Settings → API Keys** and create a new API key with these scopes:
   - `databases.read`, `databases.write`
   - `storage.read`, `storage.write`
   - `functions.read`, `functions.write`

---

## Step 2: Create Storage Bucket

1. Navigate to **Storage** in the sidebar
2. Click **"Create Bucket"**
3. Configure:
   - **Bucket ID**: `photos`
   - **Name**: `User Photos`
   - **Permissions**: Enable `Any` for both Read and Create
   - **Maximum file size**: `10MB`
   - **Allowed file extensions**: `jpg, jpeg, png, webp`
4. **Enable** "File Security" under bucket settings

---

## Step 3: Create Database & Collection

### 3.1 Create Database
1. Navigate to **Databases** in the sidebar
2. Click **"Create Database"**
3. Configure:
   - **Database ID**: `ivex_db`
   - **Name**: `IVEX Database`

### 3.2 Create Collection
1. Inside `ivex_db`, click **"Create Collection"**
2. Configure:
   - **Collection ID**: `results`
   - **Name**: `Analysis Results`
   - **Permissions**: Enable `Any` for Read, Create, Update

### 3.3 Create Attributes
Add these attributes to the `results` collection:

| Key | Type | Size | Required | Default |
|-----|------|------|----------|---------|
| `original_file_id` | String | 256 | Yes | - |
| `status` | String | 50 | Yes | `pending` |
| `face_shape` | String | 100 | No | - |
| `advice_text` | String | 5000 | No | - |
| `generated_image_url` | String | 1000 | No | - |
| `created_at` | Integer | - | No | - |

---

## Step 4: Deploy the Function

### 4.1 Install Appwrite CLI
```bash
npm install -g appwrite-cli
```

### 4.2 Login to Appwrite
```bash
appwrite login
```

### 4.3 Initialize and Deploy
```bash
cd functions/analyze-hairstyle

# Create function in Appwrite
appwrite functions create \
  --functionId "analyze-hairstyle" \
  --name "Analyze Hairstyle" \
  --runtime "python-3.12" \
  --entrypoint "main.py" \
  --timeout 300
```

### 4.4 Set Environment Variables
In Appwrite Console, go to **Functions → analyze-hairstyle → Settings → Variables**:

| Key | Value |
|-----|-------|
| `APPWRITE_API_KEY` | Your API key from Step 1 |
| `GEMINI_API_KEY` | Your Google AI Studio API key |
| `OPENROUTER_API_KEY` | Your OpenRouter API key |
| `BUCKET_ID` | `photos` |
| `DATABASE_ID` | `ivex_db` |
| `COLLECTION_ID` | `results` |

### 4.5 Set Up Event Trigger
1. Go to **Functions → analyze-hairstyle → Settings → Events**
2. Add event: `buckets.photos.files.*.create`
3. This triggers the function when any file is uploaded to the `photos` bucket

### 4.6 Deploy Code
```bash
appwrite functions createDeployment \
  --functionId "analyze-hairstyle" \
  --entrypoint "main.py" \
  --code "./"
```

---

## Step 5: Configure Flutter App

Update `lib/config/appwrite_config.dart`:

```dart
class AppwriteConfig {
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = 'YOUR_PROJECT_ID';  // ← Update this
  static const String bucketId = 'photos';
  static const String databaseId = 'ivex_db';
  static const String resultsCollectionId = 'results';
}
```

---

## Step 6: Run the App

```bash
flutter pub get
flutter run
```

---

## Testing the Flow

1. **Open the app** and tap "SCAN FACE"
2. **Take a selfie** or select from gallery
3. **Check Appwrite Console**:
   - Storage → `photos` bucket should show your image
   - Functions → `analyze-hairstyle` → Logs should show execution
   - Database → `results` collection should have a new document
4. **App receives realtime update** and displays results

---

## Troubleshooting

### Function not triggering?
- Verify event trigger is set to `buckets.photos.files.*.create`
- Check function is "Active" in the console

### API errors?
- Verify all environment variables are set correctly
- Check API key scopes include required permissions

### Image not loading?
- Ensure bucket permissions allow "Any" for Read
- Check the file was actually uploaded in Storage

---

## Architecture Diagram

```
┌─────────────────┐    Upload    ┌──────────────────┐
│   Flutter App   │ ──────────► │  Appwrite Storage │
│   (Home Screen) │              │   (photos bucket) │
└─────────────────┘              └────────┬─────────┘
        │                                 │
        │                                 │ Event Trigger
        │                                 ▼
        │                        ┌────────────────────┐
        │                        │  Appwrite Function │
        │                        │ (analyze-hairstyle)│
        │                        └─────────┬──────────┘
        │                                  │
        │              ┌───────────────────┼───────────────────┐
        │              │                   │                   │
        │              ▼                   ▼                   ▼
        │     ┌─────────────┐     ┌──────────────┐    ┌───────────────┐
        │     │  Gemini API │     │  OpenRouter  │    │Appwrite DB    │
        │     │ (Face Shape)│     │(Image Gen)   │    │(Save Results) │
        │     └─────────────┘     └──────────────┘    └───────┬───────┘
        │                                                     │
        │  Realtime Subscription                              │
        │◄────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────┐
│  Result Screen  │
│ (Shows Results) │
└─────────────────┘
```
