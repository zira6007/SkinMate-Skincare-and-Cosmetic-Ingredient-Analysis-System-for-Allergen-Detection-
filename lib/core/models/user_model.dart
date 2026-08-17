class UserModel {

  final String  userID;

  final String  name;

  final String  email;

  final String? skinType;

  final String? skinSubtype;

  final bool    isAdmin;

  final String? avatarUrl;

  final DateTime? createdAt;

  // ── Constructor ───────────────────────────────────────

  const UserModel({
    required this.userID,
    required this.name,
    required this.email,
    this.skinType,
    this.skinSubtype,
    this.isAdmin    = false,
    this.avatarUrl,
    this.createdAt,
  });


  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userID:      json['userID']     as String?  ?? '',
      name:        json['name']       as String?  ?? '',
      email:       json['email']      as String?  ?? '',
      skinType:    json['skin_type']  as String?,
      skinSubtype: json['skin_subtype'] as String?,
      isAdmin:     json['is_admin']   as bool?    ?? false,
      avatarUrl:   json['avatar_url'] as String?,
      createdAt:   json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID':     userID,
      'name':       name,
      'email':      email,
      'skin_type':  skinType,
      'is_admin':   isAdmin,
      'avatar_url': avatarUrl,
    };
  }

  UserModel copyWith({
    String?   name,
    String?   skinType,
    String?   skinSubtype,
    bool?     isAdmin,
    String?   avatarUrl,
  }) {
    return UserModel(
      userID:      userID,
      name:        name       ?? this.name,
      email:       email,
      skinType:    skinType   ?? this.skinType,
      skinSubtype: skinSubtype ?? this.skinSubtype,
      isAdmin:     isAdmin    ?? this.isAdmin,
      avatarUrl:   avatarUrl  ?? this.avatarUrl,
      createdAt:   createdAt,
    );
  }

  @override
  String toString() =>
      'UserModel(userID: $userID, name: $name, isAdmin: $isAdmin)';
}