import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/workout_split.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/nutrition_log.dart';
import '../models/nutrition_goals.dart';
import '../models/recipe.dart';
import '../models/saved_meal.dart';
import '../models/favorite_food.dart';

/// Wraps reads and writes to each user's data in Firestore.
///
/// Everything for one person lives under users/{uid} — their profile doc
/// here, and later, sub-collections underneath it for workout logs, food
/// logs, cycle logs, and body-metric logs. Keeping it all grouped under one
/// uid is what makes the security rules simple: a user can only ever read
/// or write documents under their own id.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile(UserProfile profile) {
    return _db.collection('users').doc(profile.uid).set(profile.toMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

    // --- Workout splits ---

  Future<void> addSplit(String uid, WorkoutSplit split) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('splits')
        .doc() // auto-generated id
        .set(split.toMap());
  }

  /// A live stream, not a one-time read — so if you add or rename a split
  /// elsewhere, the Main screen updates on its own without a manual
  /// refetch. Ordered to match the tab order you set.
  Stream<List<WorkoutSplit>> streamSplits(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('splits')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutSplit.fromMap(doc.id, doc.data()))
            .toList());
  }

  // --- Exercises within a split ---

  Future<void> addExercise(String uid, String splitId, Exercise exercise) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('splits')
        .doc(splitId)
        .collection('exercises')
        .doc()
        .set(exercise.toMap());
  }

  Stream<List<Exercise>> streamExercises(String uid, String splitId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('splits')
        .doc(splitId)
        .collection('exercises')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Exercise.fromMap(doc.id, doc.data()))
            .toList());
  }

  // --- Workout logs ---

  Future<void> addWorkoutLog(String uid, WorkoutLog log) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('workoutLogs')
        .doc()
        .set(log.toMap());
  }

  /// One-time read, not a stream — "last time" only needs to be fetched
  /// once when the Workout Log screen opens, not kept live-updating.
  Future<WorkoutLog?> getLatestWorkoutLog(String uid, String exerciseId) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('workoutLogs')
        .where('exerciseId', isEqualTo: exerciseId)
        .orderBy('loggedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return WorkoutLog.fromMap(doc.id, doc.data());
  }

  // --- Nutrition logs ---

  Future<void> addNutritionLog(String uid, NutritionLog log) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('nutritionLogs')
        .doc()
        .set(log.toMap());
  }

  /// Overwrites an existing entry in place (used when editing an amount) —
  /// same document, so it keeps its place in the day's log.
  Future<void> updateNutritionLog(String uid, NutritionLog log) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('nutritionLogs')
        .doc(log.id)
        .set(log.toMap());
  }

  Future<void> deleteNutritionLog(String uid, String logId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('nutritionLogs')
        .doc(logId)
        .delete();
  }

  /// A live stream of everything logged on one day — filtered by the
  /// `date` field only (equality, no `orderBy`), then sorted client-side
  /// by `loggedAt` below. A query combining a `where` on one field with an
  /// `orderBy` on a *different* field needs a Firestore composite index
  /// (see getLatestWorkoutLog's index requirement); sorting the already-
  /// small, already-filtered result list in Dart instead sidesteps that
  /// entirely — there's no reason to force you to go create another index
  /// just to show one day's food log in order.
  Stream<List<NutritionLog>> streamNutritionLogsForDate(
    String uid,
    String date,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('nutritionLogs')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final logs = snapshot.docs
              .map((doc) => NutritionLog.fromMap(doc.id, doc.data()))
              .toList();
          logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
          return logs;
        });
  }

  // --- Nutrition goals ---
  //
  // Stored as a single map field on the user's own profile doc, merged in
  // next to things like `experienceLevel` — there's only ever one active
  // set of goals, so a whole subcollection would be overkill.

  Future<void> saveNutritionGoals(String uid, NutritionGoals goals) {
    return _db.collection('users').doc(uid).set({
      'nutritionGoals': goals.toMap(),
    }, SetOptions(merge: true));
  }

  /// Live, not one-time — so saving a change on the goals editor is
  /// reflected on the Nutrition screen's progress bars the instant you
  /// navigate back, with no manual refetch.
  Stream<NutritionGoals> streamNutritionGoals(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final goalsMap = doc.data()?['nutritionGoals'];
      if (goalsMap == null) return NutritionGoals.defaults;
      return NutritionGoals.fromMap(goalsMap as Map<String, dynamic>);
    });
  }

  Future<NutritionGoals?> getNutritionGoals(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final goalsMap = data?['nutritionGoals'];
    if (goalsMap == null) return null;
    return NutritionGoals.fromMap(goalsMap as Map<String, dynamic>);
  }

  // --- Daily steps goal ---
  //
  // One number on the same user profile doc as the nutrition goals.

  Future<void> saveStepGoal(String uid, int goal) {
    return _db.collection('users').doc(uid).set({
      'stepGoal': goal,
    }, SetOptions(merge: true));
  }

  /// Live, so editing the goal updates the Activity tab's ring right away.
  /// Falls back to 10,000 until one has been saved.
  Stream<int> streamStepGoal(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final goal = doc.data()?['stepGoal'];
      return goal is num && goal > 0 ? goal.round() : 10000;
    });
  }

  // --- Recipes ---
  //
  // Dishes built from multiple ingredients with a total yield — logged by
  // the serving (see NutritionLog.fromRecipe). See lib/models/recipe.dart.

  Future<void> addRecipe(String uid, Recipe recipe) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc()
        .set(recipe.toMap());
  }

  Future<void> updateRecipe(String uid, Recipe recipe) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .set(recipe.toMap());
  }

  Future<void> deleteRecipe(String uid, String recipeId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipeId)
        .delete();
  }

  Stream<List<Recipe>> streamRecipes(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromMap(doc.id, doc.data()))
            .toList());
  }

  // --- Saved meals ---
  //
  // Groups of already-portioned foods logged together often — logging one
  // creates a separate NutritionLog per item (see NutritionLog.fromComponent).
  // See lib/models/saved_meal.dart.

  Future<void> addSavedMeal(String uid, SavedMeal meal) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .doc()
        .set(meal.toMap());
  }

  Future<void> updateSavedMeal(String uid, SavedMeal meal) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .doc(meal.id)
        .set(meal.toMap());
  }

  Future<void> deleteSavedMeal(String uid, String mealId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .doc(mealId)
        .delete();
  }

  Stream<List<SavedMeal>> streamSavedMeals(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedMeal.fromMap(doc.id, doc.data()))
            .toList());
  }

  // --- Favorite foods ---
  //
  // Individual foods starred for one-tap re-logging without searching
  // again — the "quick add" hub. See lib/models/favorite_food.dart.

  Future<void> addFavoriteFood(String uid, FavoriteFood food) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favoriteFoods')
        .doc()
        .set(food.toMap());
  }

  Future<void> deleteFavoriteFood(String uid, String favoriteId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favoriteFoods')
        .doc(favoriteId)
        .delete();
  }

  Stream<List<FavoriteFood>> streamFavoriteFoods(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favoriteFoods')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteFood.fromMap(doc.id, doc.data()))
            .toList());
  }
}
