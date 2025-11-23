# ReptiGram

ReptiGram is a dedicated social media platform for reptile enthusiasts, combining community engagement with e-commerce features. Designed for reptile keepers, breeders, and hobbyists, ReptiGram allows users to share posts, images, and videos, fostering a space to showcase their reptiles and experiences.

## Highlights:

✅ Tweet-like Posting: Users can share quick updates, photos, and videos.
✅ Reptile Marketplace: A built-in e-commerce section for buying and selling reptiles, supplies, and accessories.
✅ Fundraising Community: A feature to support reptile rescues and conservation efforts.
✅ Engaging Features: Interactive content, discussions, and potential gamification to enhance user participation.
✅ Real-time Messaging: Chat with other users with search functionality and autocomplete.

ReptiGram is more than just a social network—it's a thriving hub for reptile lovers to connect, learn, and trade. 🦎🔥

## Development Setup

### Required Versions

To ensure consistency across development environments, please use the following versions:

- **Flutter**: `3.27.4` (stable channel)
- **Dart**: `3.6.2` (comes with Flutter)
- **SDK**: `>=3.0.0 <4.0.0`

### Checking Your Versions

Verify your Flutter installation matches the required version:

```bash
flutter --version
```

Expected output:
```
Flutter 3.27.4 • channel stable
Framework • revision d8a9f9a52e
Tools • Dart 3.6.2 • DevTools 2.40.3
```

### Development Workflow

1. **Develop locally** (with hot reload):
   ```bash
   flutter run -d chrome
   ```

2. **Build for production**:
   ```bash
   flutter build web --release
   ```

3. **Deploy to Firebase Hosting**:
   ```bash
   firebase deploy --only hosting
   ```

### Version Management

For teams working on this project, it's recommended to use the same Flutter version to avoid "works on my machine" issues. [FVM (Flutter Version Management)](https://fvm.app/) locks everyone to the same version:

```bash
# Install FVM
dart pub global activate fvm

# Use specific version
fvm use 3.27.4

# Team members just run:
fvm install
fvm flutter run -d chrome
```
