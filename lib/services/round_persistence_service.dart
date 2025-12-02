import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:golf_tracker_app/models/models.dart';

class RoundPersistenceService {
  static const String _activeRoundKey = 'active_round';
  static const String _roundCourseKey = 'round_course';
  static const String _roundTeeColorKey = 'round_tee_color';
  static const String _roundHolesKey = 'round_holes';
  static const String _roundScoresKey = 'round_scores';
  static const String _roundPuttsKey = 'round_putts';
  static const String _roundChipShotsKey = 'round_chip_shots';
  static const String _roundPenaltiesKey = 'round_penalties';
  static const String _roundGirKey = 'round_gir';
  static const String _roundFairwayHitKey = 'round_fairway_hit';
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
    Map<int, int>? holePutts,
    Map<int, int>? holeChipShots,
    Map<int, int>? holePenalties,
    Map<int, bool>? holeGreenInRegulation,
    Map<int, bool>? holeFairwayHit,
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

    // Save putts
    if (holePutts != null && holePutts.isNotEmpty) {
      final puttsJson = holePutts.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString(_roundPuttsKey, json.encode(puttsJson));
    }

    // Save chip shots
    if (holeChipShots != null && holeChipShots.isNotEmpty) {
      final chipShotsJson = holeChipShots.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString(_roundChipShotsKey, json.encode(chipShotsJson));
    }

    // Save penalties
    if (holePenalties != null && holePenalties.isNotEmpty) {
      final penaltiesJson = holePenalties.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString(_roundPenaltiesKey, json.encode(penaltiesJson));
    }

    // Save GIR
    if (holeGreenInRegulation != null && holeGreenInRegulation.isNotEmpty) {
      final girJson = holeGreenInRegulation.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString(_roundGirKey, json.encode(girJson));
    }

    // Save fairway hits
    if (holeFairwayHit != null && holeFairwayHit.isNotEmpty) {
      final fairwayJson = holeFairwayHit.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString(_roundFairwayHitKey, json.encode(fairwayJson));
    }

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

      // Load putts
      final puttsJson = prefs.getString(_roundPuttsKey);
      final Map<int, int> holePutts = {};
      if (puttsJson != null) {
        final puttsMap = json.decode(puttsJson) as Map<String, dynamic>;
        puttsMap.forEach((key, value) {
          holePutts[int.parse(key)] = value as int;
        });
      }

      // Load chip shots
      final chipShotsJson = prefs.getString(_roundChipShotsKey);
      final Map<int, int> holeChipShots = {};
      if (chipShotsJson != null) {
        final chipShotsMap = json.decode(chipShotsJson) as Map<String, dynamic>;
        chipShotsMap.forEach((key, value) {
          holeChipShots[int.parse(key)] = value as int;
        });
      }

      // Load penalties
      final penaltiesJson = prefs.getString(_roundPenaltiesKey);
      final Map<int, int> holePenalties = {};
      if (penaltiesJson != null) {
        final penaltiesMap = json.decode(penaltiesJson) as Map<String, dynamic>;
        penaltiesMap.forEach((key, value) {
          holePenalties[int.parse(key)] = value as int;
        });
      }

      // Load GIR
      final girJson = prefs.getString(_roundGirKey);
      final Map<int, bool> holeGreenInRegulation = {};
      if (girJson != null) {
        final girMap = json.decode(girJson) as Map<String, dynamic>;
        girMap.forEach((key, value) {
          holeGreenInRegulation[int.parse(key)] = value as bool;
        });
      }

      // Load fairway hits
      final fairwayJson = prefs.getString(_roundFairwayHitKey);
      final Map<int, bool> holeFairwayHit = {};
      if (fairwayJson != null) {
        final fairwayMap = json.decode(fairwayJson) as Map<String, dynamic>;
        fairwayMap.forEach((key, value) {
          holeFairwayHit[int.parse(key)] = value as bool;
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
        'holePutts': holePutts,
        'holeChipShots': holeChipShots,
        'holePenalties': holePenalties,
        'holeGreenInRegulation': holeGreenInRegulation,
        'holeFairwayHit': holeFairwayHit,
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
    await prefs.remove(_roundPuttsKey);
    await prefs.remove(_roundChipShotsKey);
    await prefs.remove(_roundPenaltiesKey);
    await prefs.remove(_roundGirKey);
    await prefs.remove(_roundFairwayHitKey);
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