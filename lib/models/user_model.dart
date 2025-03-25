class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'student' or 'teacher'
  final String? className;
  final String? division;
  final bool isActive;
  final String? profileImageUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  // Getter for uid (compatibility with Firebase)
  String get uid => id;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.className,
    this.division,
    required this.isActive,
    this.profileImageUrl,
    required this.createdAt,
    this.metadata,
  });

  // Create a UserModel from JSON data
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      className: json['className'] as String?,
      division: json['division'] as String?,
      isActive: json['isActive'] as bool,
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convert UserModel to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'className': className,
      'division': division,
      'isActive': isActive,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Create a copy of this UserModel with given fields replaced with new values
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? className,
    String? division,
    bool? isActive,
    String? profileImageUrl,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      className: className ?? this.className,
      division: division ?? this.division,
      isActive: isActive ?? this.isActive,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
} 