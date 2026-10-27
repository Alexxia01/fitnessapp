# Compound

Train smarter, not harder.

Compound is a mobile app that brings workout tracking, nutrition, and cycle tracking together in one place built with Flutter and Firebase. It's a solo-developed portfolio project by me (Alexia Gurunlian), built to showcase mobile app development, from UI/UX design through to a full Firebase backend.

# What it does:
Workout tracking. Log your own workout splits and track progressive overload over time meaning the reps, weights, and rep ranges you set for yourself. Compound never prescribes a training program or tells you what to do; it tracks what you've decided to do and reflects your own history back to you, so you can see your progress and know when to push.

Nutrition tracking. Log meals and nutrition to understand how what you eat lines up with your training and your goals.

Cycle tracking. Track your menstrual cycle alongside your training and nutrition, so patterns across all three are visible in one place instead of scattered across separate apps.

# Design philosophy:
Compound is built around the idea that the app should inform, not instruct. It's not a personal trainer or a nutritionist but it's a mirror. Every number in the app comes from the user, and Compound's job is to track it, surface patterns, and get out of the way.

# Tech stack
Flutter — cross-platform mobile client (iOS & Android)
Firebase Authentication — secure email/password sign-in
Cloud Firestore — real-time user data storage
Material 3, with a custom teal / lilac / dark-purple design system built for the app

Getting started
bash
# Install dependencies
flutter pub get

# Connect your own Firebase project
flutterfire configure

# Run on a connected device or emulator
flutter run

You'll need your own Firebase project (Authentication with Email/Password enabled, and a Cloud Firestore database) — flutterfire configure generates the firebase_options.dart file this app expects.

Project structure
lib/
  main.dart              # App entry point, theme setup
  screens/
    auth/                # Sign in / sign up
    onboarding/           # Experience-level onboarding
  services/               # Auth + Firestore wrappers
  models/                 # Data models
  theme/
    app_colors.dart       # Centralized color palette
