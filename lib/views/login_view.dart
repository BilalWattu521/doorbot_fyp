import 'package:doorbot_fyp/viewmodels/auth_view_model.dart';
import 'package:doorbot_fyp/views/sign_up_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Log in to your account to continue',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => vm.loginWithGoogle(),
                      icon: Image.asset(
                        'assets/google_icon.png',
                        height: 24,
                      ),
                      label: Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.blueGrey.shade100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.blueGrey.shade200,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.blueGrey.shade200,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    CustomTextField(
                      hintText: 'you@example.com',
                      controller: emailController,
                    ),
                    SizedBox(height: 16),
                    CustomTextField(
                      hintText: 'Password',
                      obscureText: obscurePassword,
                      controller: passwordController,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Implement forgot password flow
                        },
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    vm.isLoading
                        ? CircularProgressIndicator()
                        : CustomButton(
                            text: 'Log in',
                            onPressed: () => vm.loginWithEmail(
                              emailController.text,
                              passwordController.text,
                            ),
                          ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignUpView(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign up',
                            style: TextStyle(color: Colors.blue),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
