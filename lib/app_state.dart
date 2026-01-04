import 'models/app_user.dart';

class AppState {
  // singleton instance
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;

  void clear() {
    currentUser = null;
  }
}
