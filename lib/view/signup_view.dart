import 'package:flutter/material.dart';
import 'package:doorbot_fyp/view_model/auth_view_model.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final auth = AuthViewModel();

  void _signup() async {
    if (passwordController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    try {
      await auth.signup(emailController.text, passwordController.text);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup successful")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
    }
  }

  void _signupWithGoogle() async {
    try {
      await auth.signInWithGoogle();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google signup successful")));
      // Navigate to home
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google signup failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
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
            TextField(
                controller: confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Confirm Password")),
            ElevatedButton(
                onPressed: _signup, child: const Text("Sign Up")),
            ElevatedButton(
                onPressed: _signupWithGoogle,
                child: const Text("Continue with Google"))
          ],
        ),
      ),
    );
  }
}
