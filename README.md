# Compound

A fitness and nutrition tracker for Android (Flutter + Firebase) that brings workouts, food logging and daily steps into one app. Built solo as a portfolio project.

<!-- Add a hero screenshot or short demo GIF here:
![Compound](docs/screenshots/hero.png) -->

## Features

### Workouts
- Create your own training splits (Push / Pull / Legs, Upper / Lower, anything you like) and add exercises to each one.
- Log sets, reps and weight for each exercise, with the **last session's numbers shown** so you know what to beat.
- Onboarding captures your experience level.

### Nutrition
- **Log by meal and by day** — move to any past or future date and log food there, like Cronometer. The screen always matches the real current date, even if the app stays open past midnight.
- **Search as you type** across multiple sources, with generic foods first ("Chicken Breast, Roasted") and brands after:
  - USDA FoodData Central (generic, survey and branded foods)
  - Open Food Facts (community-submitted brand products)
  - Built-in brand foods for products the databases lack
- **Cronometer-style results**: compact rows with serving size and calories, a source label, and All / Favorites / Custom tabs.
- **Barcode scanner** for packaged foods.
- **Favorites**: star any food (the star fills in purple) for quick re-logging.
- **Recipes and saved meals**: build your own, view and edit their ingredients, and log them like any other food. They also show up in search, tagged as yours.
- **Edit or delete entries**: tap a logged item to change its amount, or swipe left to delete.
- **Daily targets** for calories and macros, with a toggle between *eaten / goal* and *remaining*. Going over a target is shown in bold red.

### Activity
- Daily **step count** from Android Health Connect, shown in a progress ring toward an editable step goal.
- **Hourly steps chart** with peak hour, active hours and percent of goal.

### Everywhere
- Email sign-in with Firebase Authentication; all data is stored per user in Firestore.
- Light and dark themes, remembered between launches.

## Screenshots

<!-- Replace the placeholders with real screenshots (docs/screenshots/). -->

| Workouts | Nutrition | Food search | Activity |
|---|---|---|---|
| *screenshot: splits and exercise log* | *screenshot: day view with date bar* | *screenshot: search results with tabs* | *screenshot: step ring and hourly chart* |

| Recipe editor | Barcode scan | Targets vs remaining | Dark mode |
|---|---|---|---|
| *screenshot* | *screenshot* | *screenshot* | *screenshot* |

## Tech stack

- **Flutter / Dart**, Material 3 with a custom theme extension
- **Firebase**: Authentication and Cloud Firestore
- **Health Connect** via the `health` package (steps)
- **USDA FoodData Central** and **Open Food Facts** (food data), `mobile_scanner` (barcodes)

## Project structure

```
lib/
  data/        built-in brand foods
  models/      plain Dart data classes (food items, logs, recipes, goals, ...)
  screens/     auth, onboarding, home (workouts), nutrition, activity, workout log
  services/    Firestore, USDA, Open Food Facts, step tracking
  theme/       colors, light/dark theme controller
  widgets/     shared pieces (number input, ingredient picker, sheets)
```

## Running it

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and an Android emulator or device.
2. Create a Firebase project, enable Email/Password sign-in and Firestore, then generate `lib/firebase_options.dart` with `flutterfire configure`.
3. Get a free [USDA FoodData Central API key](https://fdc.nal.usda.gov/api-key-signup.html) and put it in `lib/services/usda_food_service.dart`.
4. For steps, install **Health Connect** on the emulator or device (built in on recent Android versions).
5. Run:

   ```
   flutter pub get
   flutter run
   ```

The Android build needs `compileSdk 37` and `minSdk 26` (already set in `android/app/build.gradle.kts`).

## Notes

- Step tracking is Android-only for now; the iOS HealthKit side is configured but untested.
- In debug builds the Activity tab has an **Add sample steps** button for testing on an emulator with no real step data. It does not appear in release builds.
- Nutrient data comes from public databases and community contributions, so entries can occasionally be incomplete.
- Not medical or dietary advice.
