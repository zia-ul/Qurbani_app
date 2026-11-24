# Deployment & Play Store Release Guide

## 1. Project Summary & Fixes Completed
- **Backend Fixes**:
  - Fixed startup configuration in `backend/package.json` (`main` and `start` script now correctly point to `src/server.js`).
  - Added dynamic port support (`process.env.PORT || 3000`) for production cloud hosts (e.g. Render, Railway, AWS, DigitalOcean).
  - Configured database parameters in `backend/config/db.js` to read from environment variables (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`) with connection pooling.
  - Created `backend/.env.example` with clear documentation of required production environment variables.
- **Frontend / Flutter Fixes**:
  - Fixed out-of-sync widget finders and text assertions in `frontend/test/users_test.dart` (`My Qurbani`, scoped `Change Password` button finder, and empty state strings).
  - Cleaned up unused imports (`add_animal_details.dart`), redundant null checks, and dead null fallback expressions.
  - Migrated legacy `url_launcher` API (`canLaunch` / `launch`) to modern `canLaunchUrl` / `launchUrl`.
  - Migrated `WillPopScope` to modern Android predictive back-compatible `PopScope`.
  - Resolved `BuildContext` across async gaps in `settings_page.dart`.
  - All test suites now pass (`11 passed, 0 failed`).
  - Configured production release signing in `frontend/android/app/build.gradle.kts` with `key.properties` support (auto-falls back to debug if keystore isn't configured yet).

---

## 2. Backend Deployment

### Recommended Cloud Platforms
- **Render / Railway / AWS EC2 / DigitalOcean Droplet / VPS**

### Deployment Steps:
1. **Set Environment Variables on Host**:
   ```env
   PORT=3000
   NODE_ENV=production
   DB_HOST=<your_mysql_host>
   DB_USER=<your_mysql_user>
   DB_PASSWORD=<your_mysql_password>
   DB_NAME=qurbani
   JWT_SECRET=<your_secure_jwt_secret>
   BASE_URL=https://<your-domain-or-public-ip>/api
   ```
2. **Import MySQL Schema**:
   Make sure your MySQL server has the `qurbani` database imported.
3. **Run Process with PM2 (Recommended for VPS/EC2)**:
   ```bash
   cd backend
   npm install --production
   npm install -g pm2
   pm2 start src/server.js --name "qurbani-backend"
   pm2 save
   pm2 startup
   ```

---

## 3. Frontend / Android Play Store Deployment

### Step 1: Update Application ID (Package Name)
Before publishing to Google Play Store, change `applicationId` from `com.example.qurbani` to your domain-based package name (e.g., `com.yourcompany.qurbani`):
- In `frontend/android/app/build.gradle.kts`:
  ```kotlin
  applicationId = "com.yourcompany.qurbani"
  ```
- In `frontend/android/app/src/main/AndroidManifest.xml` and Kotlin source folders if required.

### Step 2: Update Server URL in Frontend
Update `frontend/assets/.env`:
```env
BASE_URL=https://<your-deployed-backend-domain>/api
```

### Step 3: Generate Android Upload Keystore
Run in terminal (PowerShell / Command Prompt):
```bash
keytool -genkey -v -keystore C:\Users\ziaul\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 4: Configure `key.properties`
Create file `frontend/android/key.properties`:
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=C:\\Users\\ziaul\\upload-keystore.jks
```
*(Note: `key.properties` and `*.jks` are already added to `.gitignore` to prevent committing secrets).*

### Step 5: Build Android App Bundle (AAB) for Play Store
Run inside `frontend`:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
The output file will be generated at:
`frontend/build/app/outputs/bundle/release/app-release.aab`

### Step 6: Google Play Console Submission
1. Log in to [Google Play Console](https://play.google.com/console).
2. Create an app (select App, Free/Paid, etc.).
3. Complete all store presence requirements:
   - Privacy Policy URL
   - App category and tags
   - App Icon (512x512 PNG)
   - Feature Graphic (1024x500 PNG)
   - Phone Screenshots (min 2)
4. Go to **Release** > **Production** (or **Internal testing** first).
5. Upload `app-release.aab`.
6. Submit for Google review.
