# Flutter Example Widgets

This folder includes self-contained Flutter widgets and a tiny API client to talk to the FastAPI backend in this repo.

## Files
- `flutter_examples/auth_widgets.dart`: Widgets + API client for login/register/profile with error handling.

## Dependencies
Add these to your Flutter `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
```

## Quick Usage

```dart
import 'package:flutter/material.dart';
import 'auth_widgets.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Demo')),
      body: AuthDemo(api: AuthApi()),
    );
  }
}
```

## Base URL Notes
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Physical device: use your machine LAN IP, e.g. `http://192.168.1.10:8000`

You can override the base URL:

```dart
final api = AuthApi(config: const ApiConfig(baseUrl: 'http://127.0.0.1:8000'));
```
