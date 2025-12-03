import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage favorite courses using local storage (SharedPreferences)
class FavoritesService {
  static const String _favoritesKey = 'favorite_courses';

  /// Add a course to favorites
  Future<void> addFavorite(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    if (!favorites.contains(courseId)) {
      favorites.add(courseId);
      await prefs.setStringList(_favoritesKey, favorites);
    }
  }

  /// Remove a course from favorites
  Future<void> removeFavorite(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    favorites.remove(courseId);
    await prefs.setStringList(_favoritesKey, favorites);
  }

  /// Toggle favorite status for a course
  Future<bool> toggleFavorite(String courseId) async {
    final isFavorite = await isFavoriteCourse(courseId);

    if (isFavorite) {
      await removeFavorite(courseId);
      return false;
    } else {
      await addFavorite(courseId);
      return true;
    }
  }

  /// Check if a course is favorited
  Future<bool> isFavoriteCourse(String courseId) async {
    final favorites = await getFavorites();
    return favorites.contains(courseId);
  }

  /// Get all favorite course IDs
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}
