import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  String phone = '';
  String uid = '';
  String role = '';

  void setUserDetails(
      {required String phone, required String uid, required String role}) {
    this.phone = phone;
    this.uid = uid;
    this.role = role;
  }

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
    await prefs.setString('uid', uid);
    await prefs.setString('role', role);
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    phone = prefs.getString('phone') ?? '';
    uid = prefs.getString('uid') ?? '';
    role = prefs.getString('role') ?? '';
  }

  Future<void> clear() async {
    phone = '';
    uid = '';
    role = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
