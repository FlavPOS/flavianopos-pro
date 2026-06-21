import 'dart:convert';

/// Step 2 — Firebase Config Model
/// Field names match the Firebase Console firebaseConfig object 1:1
/// to make copy-paste easy. Plus databaseUrl (from Realtime DB tab) and
/// companyCode (your own).
class FirebaseConfig {
  // 🔹 Console firebaseConfig object — in same order as Console
  final String apiKey;
  final String authDomain;
  final String projectId;
  final String storageBucket;
  final String messagingSenderId;
  final String appId;
  final String measurementId; // optional (Console marks as optional)

  // 🔹 From Realtime Database tab (separate page in Console)
  final String databaseUrl;

  // 🔹 Your own — used as Firebase path root: companies/{companyCode}/...
  final String companyCode;
  final String companyName; // collected in Step 5

  final bool isLocked;
  final String? savedAt;
  final String? updatedAt;

  const FirebaseConfig({
    required this.apiKey,
    this.authDomain = '',
    required this.projectId,
    this.storageBucket = '',
    required this.messagingSenderId,
    required this.appId,
    this.measurementId = '',
    required this.databaseUrl,
    required this.companyCode,
    this.companyName = '',
    this.isLocked = false,
    this.savedAt,
    this.updatedAt,
  });

  FirebaseConfig copyWith({
    String? apiKey,
    String? authDomain,
    String? projectId,
    String? storageBucket,
    String? messagingSenderId,
    String? appId,
    String? measurementId,
    String? databaseUrl,
    String? companyCode,
    String? companyName,
    bool? isLocked,
    String? savedAt,
    String? updatedAt,
  }) {
    return FirebaseConfig(
      apiKey: apiKey ?? this.apiKey,
      authDomain: authDomain ?? this.authDomain,
      projectId: projectId ?? this.projectId,
      storageBucket: storageBucket ?? this.storageBucket,
      messagingSenderId: messagingSenderId ?? this.messagingSenderId,
      appId: appId ?? this.appId,
      measurementId: measurementId ?? this.measurementId,
      databaseUrl: databaseUrl ?? this.databaseUrl,
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
      isLocked: isLocked ?? this.isLocked,
      savedAt: savedAt ?? this.savedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'apiKey': apiKey,
        'authDomain': authDomain,
        'projectId': projectId,
        'storageBucket': storageBucket,
        'messagingSenderId': messagingSenderId,
        'appId': appId,
        'measurementId': measurementId,
        'databaseUrl': databaseUrl,
        'companyCode': companyCode,
        'companyName': companyName,
        'isLocked': isLocked,
        'savedAt': savedAt,
        'updatedAt': updatedAt,
      };

  factory FirebaseConfig.fromMap(Map<String, dynamic> map) => FirebaseConfig(
        apiKey: (map['apiKey'] ?? '').toString(),
        authDomain: (map['authDomain'] ?? '').toString(),
        projectId: (map['projectId'] ?? '').toString(),
        storageBucket: (map['storageBucket'] ?? '').toString(),
        messagingSenderId: (map['messagingSenderId'] ?? '').toString(),
        appId: (map['appId'] ?? '').toString(),
        measurementId: (map['measurementId'] ?? '').toString(),
        databaseUrl: (map['databaseUrl'] ?? '').toString(),
        companyCode: (map['companyCode'] ?? '').toString(),
        companyName: (map['companyName'] ?? '').toString(),
        isLocked: map['isLocked'] == true,
        savedAt: map['savedAt']?.toString(),
        updatedAt: map['updatedAt']?.toString(),
      );

  String toJsonString() => jsonEncode(toMap());

  factory FirebaseConfig.fromJsonString(String s) =>
      FirebaseConfig.fromMap(jsonDecode(s) as Map<String, dynamic>);

  bool get hasRequiredFields =>
      apiKey.trim().isNotEmpty &&
      projectId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      databaseUrl.trim().isNotEmpty &&
      companyCode.trim().isNotEmpty;
}
