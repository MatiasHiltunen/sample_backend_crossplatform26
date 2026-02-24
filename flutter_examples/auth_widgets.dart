import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  final Map<String, dynamic>? details;

  ApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.details,
  });

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message, details: $details)';
}

class ApiConfig {
  final String baseUrl;
  final Duration timeout;

  const ApiConfig({
    this.baseUrl = 'http://10.0.2.2:8000',
    this.timeout = const Duration(seconds: 10),
  });
}

class UserProfile {
  final String username;
  final String? email;
  final String? fullName;
  final bool disabled;

  UserProfile({
    required this.username,
    required this.disabled,
    this.email,
    this.fullName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      disabled: (json['disabled'] as bool?) ?? false,
    );
  }
}

class AuthApi {
  final http.Client _client;
  final ApiConfig _config;

  AuthApi({http.Client? client, ApiConfig? config})
      : _client = client ?? http.Client(),
        _config = config ?? const ApiConfig();

  Future<String> login({required String username, required String password}) async {
    final uri = Uri.parse('${_config.baseUrl}/token');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'username': username,
              'password': password,
            },
          )
          .timeout(_config.timeout);

      final data = _handleResponse(response);
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw ApiException('Token missing in response', responseBody: response.body);
      }
      return token;
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ApiException('Network error. Check your connection.');
    }
  }

  Future<void> register({
    required String username,
    required String password,
    String? email,
    String? fullName,
  }) async {
    final uri = Uri.parse('${_config.baseUrl}/register');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'email': email,
              'full_name': fullName,
            }),
          )
          .timeout(_config.timeout);

      _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ApiException('Network error. Check your connection.');
    }
  }

  Future<UserProfile> me(String token) async {
    final uri = Uri.parse('${_config.baseUrl}/users/me/');
    try {
      final response = await _client
          .get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_config.timeout);

      final data = _handleResponse(response);
      return UserProfile.fromJson(data);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ApiException('Network error. Check your connection.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final status = response.statusCode;
    Map<String, dynamic>? json;

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        // non-JSON response, ignore
      }
    }

    if (status >= 200 && status < 300) {
      return json ?? <String, dynamic>{};
    }

    final detail = json?['detail'];
    final message = detail is String
        ? detail
        : 'Request failed with status $status';

    throw ApiException(
      message,
      statusCode: status,
      responseBody: response.body,
      details: json,
    );
  }
}

class ApiErrorBanner extends StatelessWidget {
  final ApiException? error;

  const ApiErrorBanner({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        error!.message,
        style: TextStyle(color: Colors.red.shade800),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final AuthApi api;
  final ValueChanged<String> onLoggedIn;

  const LoginForm({super.key, required this.api, required this.onLoggedIn});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  ApiException? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await widget.api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onLoggedIn(token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApiErrorBanner(error: _error),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Log in'),
        ),
      ],
    );
  }
}

class RegisterForm extends StatefulWidget {
  final AuthApi api;
  final VoidCallback onRegistered;

  const RegisterForm({super.key, required this.api, required this.onRegistered});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isLoading = false;
  ApiException? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.api.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
      );
      if (!mounted) return;
      widget.onRegistered();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApiErrorBanner(error: _error),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email (optional)'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(labelText: 'Full name (optional)'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Register'),
        ),
      ],
    );
  }
}

class ProfileView extends StatelessWidget {
  final AuthApi api;
  final String token;

  const ProfileView({super.key, required this.api, required this.token});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: api.me(token),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error is ApiException
              ? snapshot.error as ApiException
              : ApiException('Unexpected error.');
          return ApiErrorBanner(error: error);
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Text('No profile data.');
        }

        return Card(
          child: ListTile(
            title: Text(profile.username),
            subtitle: Text([
              if (profile.fullName != null) profile.fullName!,
              if (profile.email != null) profile.email!,
            ].join(' • ')),
            trailing: profile.disabled
                ? const Icon(Icons.block, color: Colors.red)
                : const Icon(Icons.verified, color: Colors.green),
          ),
        );
      },
    );
  }
}

class AuthDemo extends StatefulWidget {
  final AuthApi api;

  const AuthDemo({super.key, required this.api});

  @override
  State<AuthDemo> createState() => _AuthDemoState();
}

class _AuthDemoState extends State<AuthDemo> {
  String? _token;
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_token == null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showRegister ? 'Create account' : 'Welcome back',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => setState(() => _showRegister = !_showRegister),
                  child: Text(_showRegister ? 'Have an account?' : 'New here?'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_showRegister)
              RegisterForm(
                api: widget.api,
                onRegistered: () => setState(() => _showRegister = false),
              )
            else
              LoginForm(
                api: widget.api,
                onLoggedIn: (token) => setState(() => _token = token),
              ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => setState(() => _token = null),
                  child: const Text('Log out'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProfileView(api: widget.api, token: _token!),
          ],
        ],
      ),
    );
  }
}
