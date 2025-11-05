enum ClubType {
  driver,
  wood3,
  wood5,
  wood7,
  hybrid,
  iron2,
  iron3,
  iron4,
  iron5,
  iron6,
  iron7,
  iron8,
  iron9,
  pitchingWedge,
  gapWedge,
  sandWedge,
  lobWedge,
  varWedge,
  putter;

  String get displayName {
    switch (this) {
      case ClubType.driver:
        return 'Driver';
      case ClubType.wood3:
        return '3 Wood';
      case ClubType.wood5:
        return '5 Wood';
      case ClubType.wood7:
        return '7 Wood';
      case ClubType.hybrid:
        return 'Hybrid';
      case ClubType.iron2:
        return '2 Iron';
      case ClubType.iron3:
        return '3 Iron';
      case ClubType.iron4:
        return '4 Iron';
      case ClubType.iron5:
        return '5 Iron';
      case ClubType.iron6:
        return '6 Iron';
      case ClubType.iron7:
        return '7 Iron';
      case ClubType.iron8:
        return '8 Iron';
      case ClubType.iron9:
        return '9 Iron';
      case ClubType.pitchingWedge:
        return 'PW';
      case ClubType.gapWedge:
        return 'GW';
      case ClubType.sandWedge:
        return 'SW';
      case ClubType.lobWedge:
        return 'LW';
      case ClubType.varWedge:
        return 'Custom Wedge';
      case ClubType.putter:
        return 'Putter';
    }
  }

  // Convert to string for storage
  String toJson() => name;

  // Create from string
  static ClubType fromJson(String value) {
    return ClubType.values.firstWhere((e) => e.name == value);
  }
}
