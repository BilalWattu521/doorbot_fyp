import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  User? get currentUser => _auth.currentUser;

  String get displayName {
    if (_auth.currentUser?.displayName != null &&
        _auth.currentUser!.displayName!.isNotEmpty) {
      return _auth.currentUser!.displayName!;
    }
    return "Guest User";
  }

  String get email {
    return _auth.currentUser?.email ?? "No email";
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      setLoading(true);

      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // reload user to ensure latest data
      await userCredential.user?.reload();
      final refreshedUser = _auth.currentUser;

      if (!(refreshedUser?.emailVerified ?? false)) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: "email-not-verified",
          message:
              "Your email is not verified yet. Please check your inbox or spam folder.",
        );
      }

      debugPrint('User logged in successfully: ${refreshedUser?.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during login: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      throw Exception("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<void> signUpWithEmail(
      String email, String password, String name) async {
    try {
      setLoading(true);

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await result.user?.updateDisplayName(name);
      await result.user?.reload();

      await result.user?.sendEmailVerification();

      debugPrint("Verification email sent to: $email");
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during signup: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during signup: $e');
      throw Exception("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

Future<void> loginWithGoogle() async {
  try {
    setLoading(true);

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled the sign-in
      setLoading(false);
      return;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);

    User? user = userCredential.user;

    if (user != null) {
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(googleUser.displayName ?? "Google User");
        await user.reload();
      }
    }

    debugPrint("Google login successful for: ${_auth.currentUser?.email}");
  } on FirebaseAuthException catch (e) {
    debugPrint('FirebaseAuthException during Google Sign-In: ${e.code} ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('General exception during Google Sign-In: $e');
    throw Exception("Google Sign-In failed.");
  } finally {
    setLoading(false);
  }
}




  Future<void> resendVerificationEmail(
      String email, String password) async {
    try {
      setLoading(true);

      // sign in temporarily to be able to send verification email
      final userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.sendEmailVerification();

      debugPrint(
          "Verification email resent to: ${userCredential.user?.email}");

      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'FirebaseAuthException during resend verification: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      throw Exception(
          "Failed to send verification email. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    debugPrint("User logged out.");
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint("Password reset email sent to: $email");
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'FirebaseAuthException during password reset: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      throw Exception("Failed to send password reset email.");
    }
  }

}
