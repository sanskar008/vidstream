class ApiConfig {
  // Production backend URL
  static const String baseUrl = 'https://vidstream-40tx.onrender.com/api';
  static const String socketUrl = 'https://vidstream-40tx.onrender.com';

  // Local development URLs (uncomment to use locally)
  // For Android emulator use: http://10.0.2.2:5000/api
  // For iOS simulator use: http://localhost:5000/api
  // For physical device use: http://YOUR_COMPUTER_IP:5000/api
  // static const String baseUrl = 'http://10.0.2.2:5000/api';
  // static const String socketUrl = 'http://10.0.2.2:5000';

  static String get authUrl => '$baseUrl/auth';
  static String get streamsUrl => '$baseUrl/streams';
  static String get profilesUrl => '$baseUrl/profiles';
}
