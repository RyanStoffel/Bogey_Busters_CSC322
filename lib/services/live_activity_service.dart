import 'dart:io';
import 'package:live_activities/live_activities.dart';
import 'package:geolocator/geolocator.dart';

/// Service for managing iOS Live Activities during a golf round
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal() {
    _initializePlugin();
  }

  final _liveActivitiesPlugin = LiveActivities();
  String? _activityId;
  bool _isActive = false;
  bool _isInitialized = false;

  /// Initialize the Live Activities plugin
  Future<void> _initializePlugin() async {
    if (!Platform.isIOS || _isInitialized) return;
    
    try {
      // Initialize without app group for basic functionality
      await _liveActivitiesPlugin.init(appGroupId: '');
      _isInitialized = true;
      print('Live Activities plugin initialized');
    } catch (e) {
      print('Failed to initialize Live Activities plugin: $e');
      _isInitialized = false;
    }
  }

  /// Check if Live Activities are supported on this device
  Future<bool> get areActivitiesEnabled async {
    if (!Platform.isIOS) return false;
    try {
      final status = await _liveActivitiesPlugin.areActivitiesEnabled();
      return status;
    } catch (e) {
      print('Error checking Live Activities status: $e');
      return false;
    }
  }

  /// Start a Live Activity for a golf round
  /// 
  /// [roundId] - Unique identifier for this round
  /// [courseName] - Name of the golf course
  /// [initialHole] - Starting hole number
  /// [initialDistance] - Initial distance to green in yards
  /// [initialScore] - Initial score relative to par
  Future<bool> startActivity({
    required String roundId,
    required String courseName,
    required int initialHole,
    required int initialDistance,
    required int initialScore,
  }) async {
    if (!Platform.isIOS) {
      print('Live Activities are only supported on iOS');
      return false;
    }

    // Ensure plugin is initialized
    if (!_isInitialized) {
      await _initializePlugin();
      if (!_isInitialized) {
        print('Failed to initialize Live Activities plugin');
        return false;
      }
    }

    try {
      final enabled = await areActivitiesEnabled;
      if (!enabled) {
        print('Live Activities are not enabled on this device');
        return false;
      }

      // Create the activity data with correct attribute names
      final activityData = {
        'attributes': {
          'roundId': roundId,
        },
        'contentState': {
          'holeNumber': initialHole,
          'distanceToGreen': initialDistance,
          'relativeToPar': initialScore,
          'courseName': courseName,
        },
      };

      print('📊 Starting Live Activity with data:');
      print('  Hole: $initialHole');
      print('  Distance: $initialDistance yds');
      print('  Score: $initialScore');
      print('  Course: $courseName');

      // Start the activity
      final activityId = await _liveActivitiesPlugin.createActivity(activityData);

      if (activityId != null) {
        _activityId = activityId;
        _isActive = true;
        print('Live Activity started: $activityId');
        return true;
      } else {
        print('Failed to start Live Activity');
        return false;
      }
    } catch (e) {
      print('Error starting Live Activity: $e');
      return false;
    }
  }

  /// Update the Live Activity with new data
  /// 
  /// [holeNumber] - Current hole number
  /// [distanceToGreen] - Distance to green in yards
  /// [relativeToPar] - Score relative to par
  /// [courseName] - Course name (optional, defaults to existing value)
  Future<bool> updateActivity({
    required int holeNumber,
    required int distanceToGreen,
    required int relativeToPar,
    String? courseName,
  }) async {
    if (!_isActive || _activityId == null) {
      print('No active Live Activity to update');
      return false;
    }

    try {
      final updateData = <String, dynamic>{
        'holeNumber': holeNumber,
        'distanceToGreen': distanceToGreen,
        'relativeToPar': relativeToPar,
      };

      if (courseName != null) {
        updateData['courseName'] = courseName;
      }

      await _liveActivitiesPlugin.updateActivity(
        _activityId!,
        updateData,
      );

      return true;
    } catch (e) {
      print('Error updating Live Activity: $e');
      return false;
    }
  }

  /// End the Live Activity
  Future<bool> endActivity() async {
    if (!_isActive || _activityId == null) {
      print('No active Live Activity to end');
      return false;
    }

    try {
      await _liveActivitiesPlugin.endActivity(_activityId!);
      _activityId = null;
      _isActive = false;
      print('Live Activity ended');
      return true;
    } catch (e) {
      print('Error ending Live Activity: $e');
      return false;
    }
  }

  /// Get the current activity status
  bool get isActive => _isActive;

  /// Get the current activity ID
  String? get activityId => _activityId;

  /// Calculate distance in yards between two coordinates
  int calculateDistanceInYards(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLon,
      endLat,
      endLon,
    );
    return (distanceInMeters * 1.09361).round(); // Convert to yards
  }
}