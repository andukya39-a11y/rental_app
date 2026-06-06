All requested features have been implemented:

1. **Demo Data**: Generated 15 realistic Zanzibar rental house demo data entries in JSON format (saved as `demo_data_tshilling.json` in the project root). The data includes fields: title, price (in TShilling), currency, location, description, imageUrl (using Unsplash/Pexels placeholder URLs), verified, verifiedBy, latitude, longitude.

2. **Shehia Verification Badge**:
   - Added `isVerified` boolean field to `HouseModel` to track verification status by Shehia (admin).
   - In `AddHouseScreen`, removed the "Mark as verified" switch so only admins (Shehia) can verify houses via the admin screen.
   - In `AdminVerificationScreen` (profile tab), houses are separated into verified and unverified lists, with verification/unverification buttons for admins.
   - In `HouseDetailScreen`, a green verified badge with check icon and text "Shehia Verified" is displayed when `isVerified` is true; otherwise, orange text "Pending Verification" is shown.

3. **Google Maps Integration**:
   - Added `google_maps_flutter` and `geolocator` dependencies to `pubspec.yaml`.
   - Added `latitude` and `longitude` fields (nullable doubles) to `HouseModel`.
   - In `HouseDetailScreen`, implemented an interactive Google Map showing:
     - A marker at the house's location (if latitude/longitude available).
     - The user's current location (with permission) and a button to center the map on the user's location.
     - A button to open the location in the Google Maps app for alternative viewing.
   - The map is displayed inline in the house detail screen for a seamless experience.

4. **Local Notifications**:
   - Added `flutter_local_notifications` dependency to `pubspec.yaml`.
   - Initialized the notification plugin in `main.dart`.
   - In `LoginScreen`, after successful login, a notification is shown with:
     - Title: "Zanzi Renta"
     - Body: "New verified rentals available near you."
   - Uses platform-specific initialization (AndroidInitializationSettings and DarwinInitializationSettings for iOS).

5. **Additional Improvements**:
   - Modified `AddHouseScreen` to automatically set `userId` from the currently authenticated user when adding a house.
   - Updated `HouseService` to handle the `userId` field when adding houses.
   - Ensured the UI follows a clean, modern design using the existing theme colors.
   - All changes are beginner-friendly and maintain the existing app structure.

To use the demo data:
1. Copy the JSON array from `demo_data_tshilling.json`.
2. Paste it into your Firestore `houses` collection (each object becomes a document).
3. Ensure your Firestore rules allow read/write for testing or adjust as needed.

To test the features:
1. Run the app on an Android/iOS emulator or physical device.
2. Log in (or create an account) to see the notification.
3. Navigate to the Profile tab (bottom navigation) to access the admin verification screen.
4. Tap on any house in the Explore tab to see the detailed view with map and verification badge.

Note: For Google Maps to work properly, you need to:
- Obtain an API key from Google Cloud Console.
- Add the API key to `android/app/src/main/AndroidManifest.xml` (for Android) and `ios/Runner/AppDelegate.swift` (for iOS).
- Enable the Google Maps SDK for Android and iOS in your Google Cloud project.

The app is now ready for demonstration with all requested features implemented.