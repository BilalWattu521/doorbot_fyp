import 'package:flutter/material.dart';
import 'package:doorbot_fyp/view/signup_view.dart';
import 'package:doorbot_fyp/view_model/auth_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final auth = AuthViewModel();

  void _login() async {
    try {
      await auth.login(emailController.text, passwordController.text);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful")));
      // Navigate to home screen if you have one
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
    }
  }

  void _loginWithGoogle() async {
    try {
      await auth.signInWithGoogle();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google login successful")));
      // Navigate to home
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google sign-in failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email")),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password")),
            ElevatedButton(
                onPressed: _login, child: const Text("Login")),
            ElevatedButton(
                onPressed: _loginWithGoogle,
                child: const Text("Continue with Google")),
            TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupView()));
                },
                child: const Text("Sign Up"))
          ],
        ),
      ),
    );
  }
}
