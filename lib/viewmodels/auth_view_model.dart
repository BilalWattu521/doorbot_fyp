import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool isLoading = false;

  Future<void> loginWithEmail(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // handle successful login (e.g. navigate, show success message)
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during login: ${e.code} ${e.message}');
      // Show a user-friendly error message
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // handle successful sign up
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during sign up: ${e.code} ${e.message}');
      // Show user-friendly error message
    } catch (e) {
      debugPrint('Unexpected error during sign up: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("Google Sign-In cancelled by user.");
        isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      // handle successful login (navigate, show message, etc.)
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during Google Sign-In: ${e.code} ${e.message}');
    } on Exception catch (e) {
      debugPrint('General exception during Google Sign-In: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
