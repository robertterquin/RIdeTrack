import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for handling Firebase Authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up a new user with email and password
  /// Returns the UserCredential on success
  /// Throws FirebaseAuthException on error
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    UserCredential? userCredential;
    
    try {
      // Create user with Firebase Auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ User account created successfully: ${userCredential.user?.uid}');

      // Try to store additional user data in Firestore with a timeout
      try {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'name': name,
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
              'totalRides': 0,
              'totalDistance': 0.0,
              'totalTime': 0,
            })
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('⚠️ Firestore write timed out after 5 seconds');
                throw TimeoutException('Firestore write timed out');
              },
            );
        print('✅ User profile saved to Firestore');
      } catch (firestoreError) {
        // Log Firestore error but don't fail signup
        print('⚠️ Warning: Could not save user profile to Firestore: $firestoreError');
        print('💡 Please enable Cloud Firestore in Firebase Console: https://console.firebase.google.com/');
        // Don't rethrow - account was created successfully
      }

      // Send email verification (also with timeout)
      try {
        await userCredential.user?.sendEmailVerification().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Email verification timed out');
          },
        );
        print('✅ Verification email sent');
      } catch (emailError) {
        print('⚠️ Warning: Could not send verification email: $emailError');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Log detailed error for debugging
      print('❌ FirebaseAuthException during signup:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      // Catch any other errors
      print('❌ Unexpected error during signup: $e');
      rethrow;
    }
  }

  /// Sign in an existing user with email and password
  /// Returns the UserCredential on success
  /// Throws FirebaseAuthException on error
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send email verification to the current user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Check if a user exists with the given email
  /// Returns true if user exists, false otherwise
  Future<bool> checkUserExists(String email) async {
    try {
      // Send a password reset email - if it succeeds, user exists
      // We won't actually send the email, just check if it would succeed
      final userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      
      return userDoc.docs.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking user existence: $e');
      // If Firestore fails, try to send reset email as fallback verification
      try {
        await _auth.sendPasswordResetEmail(email: email);
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  /// Send password reset email (direct method for forgot password flow)
  Future<void> resetPasswordViaEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Change password with email and current password verification
  /// Verifies the email matches the current user before changing password
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        throw 'No user is currently logged in';
      }

      // Verify the email matches the current user's email
      if (user.email?.toLowerCase() != email.toLowerCase()) {
        throw 'Email does not match the logged-in user';
      }

      print('🔄 Re-authenticating user with email: $email');
      
      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      print('✅ Re-authentication successful, updating password...');
      
      // Update password
      await user.updatePassword(newPassword);
      
      print('✅ Password updated successfully');

      // Update Firestore to track password change timestamp
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
              'lastPasswordChange': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('⚠️ Firestore update timed out');
              },
            );
        print('✅ Password change timestamp updated in Firestore');
      } catch (firestoreError) {
        print('⚠️ Warning: Could not update Firestore: $firestoreError');
        // Don't fail password change if Firestore update fails
      }

    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please enable it in Firebase Console under Authentication > Sign-in method.';
      default:
        return 'Authentication error (${e.code}): ${e.message ?? "Unknown error"}';
    }
  }
}
