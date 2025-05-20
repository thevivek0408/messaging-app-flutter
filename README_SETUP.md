# Flutter Messaging App - Setup & Run Instructions

## Requirements

### 1. Flutter SDK
- Install Flutter: https://docs.flutter.dev/get-started/install
- Make sure `flutter` is in your PATH.

### 2. Dart SDK
- Comes with Flutter, no separate install needed.

### 3. Node.js & npm
- Install Node.js (includes npm): https://nodejs.org/

### 4. Additional dependencies
- Your Flutter project uses:
  - `file_picker`
  - `image_picker`
  - `emoji_picker_flutter`
  - `socket_io_client`
- These are already listed in your `pubspec.yaml`.

---

## Installation & Execution Steps

### 1. Clone or Download the Project
```sh
git clone <your-repo-url>
cd messaging
```

### 2. Install Flutter Dependencies
```sh
flutter pub get
```

### 3. Install Node.js Server Dependencies
```sh
npm install socket.io
```

### 4. Run the Node.js Socket Server
```sh
node server.js
```
- The server will start on `http://<your-local-ip>:3000` (e.g., `http://192.168.29.63:3000`).

### 5. Run the Flutter App

#### For Mobile (Android/iOS):
```sh
flutter run
```

#### For Web (Localhost Only):
```sh
flutter run -d chrome
```

#### For Web (Accessible on Local Network):
```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```
- Open `http://<your-local-ip>:8080` in your browser (e.g., `http://192.168.29.63:8080`).
- This allows other devices on your network to access the app.

### 6. Connect Devices/Browsers
- Open the app on multiple devices or browser tabs.
- Make sure all devices are on the same local network as the server.

---

## Notes

- If you change the server IP, update it in `main.dart` (`_initSocket()`).
- For web, allow camera/microphone permissions if prompted.
- To use file/camera features on mobile, ensure you have the required permissions in `AndroidManifest.xml` and `Info.plist`.

---

## GitHub Upload (Optional)

1. Initialize git (if not already):
   ```sh
   git init
   ```
2. Add all files:
   ```sh
   git add .
   ```
3. Commit:
   ```sh
   git commit -m "Initial commit"
   ```
4. Create a new GitHub repo and add it as remote:
   ```sh
   git remote add origin <your-github-repo-url>
   ```
5. Push:
   ```sh
   git push -u origin main
   ```

---

Let me know if you need help with any step!
