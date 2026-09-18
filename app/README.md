# Aegis App

Flutter mobile client — voice-first check-in, teach-back, daily stories, and rules dictionary.

## Structure

```
lib/
├── model/           # CheckinFrame, DailyStory, RuleEntry
├── screens/         # checkin, dictionary, home, learn, profile, splash
├── services/        # checkin_socket, polly_tts, progress, rules, speech, story
├── theme/           # app_theme.dart
├── widgets/         # aegis_widgets, story_links_section
└── config.dart      # backend host config
```

## Setup

```bash
flutter pub get
```

## Running

Update `lib/config.dart`'s backend host to your LAN IP or `10.0.2.2` (Android emulator), then:

```bash
flutter run
```