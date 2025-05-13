# UrbanEye

**Two Flutter apps (User & Admin) with a Python Flask backend for detecting and reporting urban issues.**

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Getting the Code](#getting-the-code)
4. [Backend Setup (Flask)](#backend-setup-flask)
5. [User App Setup](#user-app-setup)
6. [Admin App Setup](#admin-app-setup)
7. [Directory Structure](#directory-structure)
8. [Running the Apps](#running-the-apps)
9. [Building Release APKs](#building-release-apks)
10. [Environment Configuration](#environment-configuration)
11. [Troubleshooting](#troubleshooting)
12. [Contributing](#contributing)

---

## Project Overview

UrbanEye lets citizens snap photos of city issues (potholes, graffiti, overgrown grass, etc.), automatically detects them via a YOLO model, and submit detailed reports with location. An Admin app lets city staff filter, sort, paginate, and update report statuses.

## Prerequisites

* **Flutter** (>=3.0) installed: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
* **Android SDK / Xcode** (for mobile platforms)
* **Dart SDK** (comes with Flutter)
* **Python 3.8+**
* **pip** for Python packages

## Getting the Code

```bash
# Clone the repo
git clone https://github.com/your-org/urbaneye.git
cd urbaneye
```

## Backend Setup (Flask)

1. Create and activate a Python venv:

   ```bash
   python3 -m venv venv
   source venv/bin/activate   # macOS/Linux
   venv\Scripts\activate    # Windows
   ```
2. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```
3. Initialize the database and models:

   ```bash
   python server.py  # creates users.db and directories
   ```
4. Start the server:

   ```bash
   python server.py
   ```

   By default it listens on [http://0.0.0.0:5000](http://0.0.0.0:5000)

## User App Setup

1. Navigate to the Flutter project root:

   ```bash
   cd flutter_app
   ```
2. Get packages:

   ```bash
   flutter pub get
   ```
3. Configure the API base URL in `lib/services/api_service.dart`, e.g.:

   ```dart
   static const _baseUrl = 'http://10.0.2.2:5000';
   ```
4. Run on emulator or device:

   ```bash
   flutter run -t lib/main.dart
   ```

## Admin App Setup

The same codebase uses two entrypoints via product flavors:

1. Ensure flavors are set up in `android/app/build.gradle`:

   ```groovy
   flavorDimensions "app"
   productFlavors {
     user { applicationId "com.yourorg.urbaneye" }
     admin { applicationId "com.yourorg.urbaneye.admin" }
   }
   ```
2. Run the Admin flavor:

   ```bash
   flutter run --flavor admin -t lib/admin_main.dart
   ```

## Directory Structure

```
/                   - repo root
├── flutter_app/    - Flutter user + admin apps
│   ├── lib/main.dart       - User entrypoint
│   ├── lib/admin_main.dart - Admin entrypoint
│   └── lib/                - Dart sources, screens, services
├── server/         - Flask backend (server.py)
│   └── users.db, images/   - DB and uploaded images
├── requirements.txt         - Python deps
└── README.md                - this file
```

## Running the Apps

* **User:** `flutter run -t lib/main.dart`
* **Admin:** `flutter run --flavor admin -t lib/admin_main.dart`

## Building Release APKs

* **User APK:**

  ```bash
  flutter build apk --flavor user -t lib/main.dart
  ```
* **Admin APK:**

  ```bash
  flutter build apk --flavor admin -t lib/admin_main.dart
  ```

## Environment Configuration

If you need to override `_baseUrl` without editing code, you can use a Dart `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://myserver.com \
  -t lib/main.dart
```

And read it in code via `const String.fromEnvironment('API_BASE_URL')`.

## Troubleshooting

* **Flutter commands not recognized**: ensure `flutter/bin` is on your PATH.
* **Permission errors on Android**: check `AndroidManifest.xml` includes `INTERNET` and location permissions.
* **Stuck on NDK / compileSdk**: set `minSdkVersion 21` and `compileSdkVersion 33+` in `android/app/build.gradle`.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Commit & push your changes
4. Open a Pull Request

---

*Happy Coding!*
