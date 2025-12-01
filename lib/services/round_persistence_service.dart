import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:golf_tracker_app/models/models.dart';

class RoundPersistenceService {
  static const String _activeRoundKey = 'active_round';
  static const String _roundCourseKey = 'round_course';
  static const String _roundTeeColorKey = 'round_tee_color';
  static const String _roundHolesKey = 'round_holes';
  static const String _roundScoresKey = 'round_scores';
  static const String _currentHoleIndexKey = 'current_hole_index';
  static const String _roundStartTimeKey = 'round_start_time';

  /// Check if there's an active round in progress
  Future<bool> hasActiveRound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activeRoundKey) ?? false;
  }

  /// Save the current round state
  Future<void> saveRoundState({
    required Course course,
    required String teeColor,
    required List<Hole> holes,
    required Map<int, int> holeScores,
    required int currentHoleIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Mark as active round
    await prefs.setBool(_activeRoundKey, true);

    // Save course data
    await prefs.setString(_roundCourseKey, json.encode(course.toJson()));

    // Save tee color
    await prefs.setString(_roundTeeColorKey, teeColor);

    // Save holes data
    final holesJson = holes.map((h) => h.toJson()).toList();
    await prefs.setString(_roundHolesKey, json.encode(holesJson));

    // Save scores (convert Map<int, int> to JSON-serializable format)
    final scoresJson = holeScores.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString(_roundScoresKey, json.encode(scoresJson));

    // Save current hole index
    await prefs.setInt(_currentHoleIndexKey, currentHoleIndex);

    // Save start time if not already set
    if (!prefs.containsKey(_roundStartTimeKey)) {
      await prefs.setString(_roundStartTimeKey, DateTime.now().toIso8601String());
    }

    print('✅ Round state saved - Hole ${currentHoleIndex + 1}, ${holeScores.length} scores recorded');
  }

  /// Load the saved round state
  Future<Map<String, dynamic>?> loadRoundState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!await hasActiveRound()) {
      return null;
    }

    try {
      // Load course
      final courseJson = prefs.getString(_roundCourseKey);
      if (courseJson == null) return null;
      final course = Course.fromJson(json.decode(courseJson));

      // Load tee color
      final teeColor = prefs.getString(_roundTeeColorKey);
      if (teeColor == null) return null;

      // Load holes
      final holesJson = prefs.getString(_roundHolesKey);
      if (holesJson == null) return null;
      final holesList = (json.decode(holesJson) as List)
          .map((h) => Hole.fromJson(h as Map<String, dynamic>))
          .toList();

      // Load scores
      final scoresJson = prefs.getString(_roundScoresKey);
      final Map<int, int> holeScores = {};
      if (scoresJson != null) {
        final scoresMap = json.decode(scoresJson) as Map<String, dynamic>;
        scoresMap.forEach((key, value) {
          holeScores[int.parse(key)] = value as int;
        });
      }

      // Load current hole index
      final currentHoleIndex = prefs.getInt(_currentHoleIndexKey) ?? 0;

      // Load start time
      final startTimeStr = prefs.getString(_roundStartTimeKey);
      final startTime = startTimeStr != null ? DateTime.parse(startTimeStr) : DateTime.now();

      print('✅ Round state loaded - Hole ${currentHoleIndex + 1}, ${holeScores.length} scores recorded');

      return {
        'course': course,
        'teeColor': teeColor,
        'holes': holesList,
        'holeScores': holeScores,
        'currentHoleIndex': currentHoleIndex,
        'startTime': startTime,
      };
    } catch (e) {
      print('Error loading round state: $e');
      // Clear corrupted data
      await clearRoundState();
      return null;
    }
  }

  /// Clear the saved round state (when round is completed or cancelled)
  Future<void> clearRoundState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRoundKey);
    await prefs.remove(_roundCourseKey);
    await prefs.remove(_roundTeeColorKey);
    await prefs.remove(_roundHolesKey);
    await prefs.remove(_roundScoresKey);
    await prefs.remove(_currentHoleIndexKey);
    await prefs.remove(_roundStartTimeKey);
    print('✅ Round state cleared');
  }

  /// Get round duration
  Future<Duration?> getRoundDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeStr = prefs.getString(_roundStartTimeKey);
    if (startTimeStr == null) return null;

    final startTime = DateTime.parse(startTimeStr);
    return DateTime.now().difference(startTime);
  }
}