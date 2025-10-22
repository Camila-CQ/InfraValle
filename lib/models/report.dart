import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  String? id;
  String description;
  String userId;
  String? imageUrl;
  Timestamp timestamp;

  Report({
    this.id,
    required this.description,
    required this.userId,
    this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'userId': userId,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }

  static Report fromMap(String id, Map<String, dynamic> map) {
    return Report(
      id: id,
      description: map['description'],
      userId: map['userId'],
      imageUrl: map['imageUrl'],
      timestamp: map['timestamp'],
    );
  }
}
