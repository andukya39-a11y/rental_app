# Firebase Authentication Setup Guide

## Email/Password Authentication (Already Working)

Email/password authentication is already configured and working in the app.

## Google Sign-In Setup

To enable Google Sign-In in your Flutter app:

### 1. Get OAuth Client ID from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `mwaki-s-zanzi-rentalapp`
3. Go to Project Settings (gear icon) > General tab
4. Scroll down to "Your apps" section
5. Find your Android app (`com.example.rental_app`)
6. Under "SHA-1 certificate fingerprints", you'll need to add your SHA-1 key
7. For development, you can get your debug SHA-1 using:
   ```
   keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore
   ```
   (Password is `android` if prompted)

8. After adding SHA-1, Google Services will auto-download a new `google-services.json`
9. Replace your existing `android/app/google-services.json` with the new one

### 2. Enable Google Sign-In Provider

1. In Firebase Console, go to Authentication > Sign-in method
2. Click on "Google" provider
3. Enable it
4. Click Save

### 3. Configure iOS (Optional but Recommended)

1. In Firebase Console, under Project Settings > General
2. Find your iOS app (`com.example.rentalApp`)
3. Download the new `GoogleService-Info.plist`
4. Replace `ios/Runner/GoogleService-Info.plist` with the new file

### 4. Update AndroidManifest for Web (Optional)

If you plan to support web:
1. Add your web client ID to `web/index.html`:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```

## Phone Authentication Setup

Phone authentication requires additional setup:

### 1. Enable Phone Provider

1. In Firebase Console, go to Authentication > Sign-in method
2. Click on "Phone" provider
3. Enable it
4. Click Save

### 2. Setup SHA-1 for Production (Required for Phone Auth)

Phone authentication requires a valid SHA-1 certificate:
1. Follow step 1 above to get your SHA-1
2. Add it to your Firebase project settings
3. Download updated config files

## Testing Credentials

For testing, you can use:
- Email: `test@example.com`
- Password: `password123` (must be at least 6 characters)

## Troubleshooting

### Common Issues:

1. "null" client ID error: Make sure you've downloaded updated config files after enabling providers
2. Sign-in fails: Check that you've added SHA-1 certificate fingerprints
3. Plugin not found: Run `flutter pub get` after updating dependencies
4. Build fails: Run `flutter clean` then `flutter pub get`

## Current Implementation

The app currently uses a custom authentication screen with:
- Email/password sign in/register
- Placeholder buttons for Google and Phone sign in (showing toast messages)
- Proper form validation
- Loading states
- Navigation to home screen on successful auth

To implement actual Google/Phone sign in:
1. Follow the setup steps above
2. Replace the placeholder onPressed handlers with actual Firebase UI Auth calls
3. Or use Firebase Auth SDK directly with GoogleSignIn and FirebaseAuth packages

## Resources

- Firebase Auth Documentation: https://firebase.google.com/docs/auth
- Firebase UI Auth: https://pub.dev/packages/firebase_ui_auth
- Google Sign-In Setup: https://firebase.google.com/docs/auth/android/google-signin
- Phone Auth Setup: https://firebase.google.com/docs/auth/android/phone-auth