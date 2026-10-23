class ProgressEntry {
  final int id;
  final String imagePath;
  final String category; 
  final String dateTaken;

  ProgressEntry({
    required this.id,
    required this.imagePath,
    required this.category,
    required this.dateTaken,
  });

  factory ProgressEntry.fromMap(Map<String, dynamic> map) {
    return ProgressEntry(
      id: map['id'] as int,
      imagePath: map['image_path'] as String,
      category: map['category'] as String,
      dateTaken: map['date_taken'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'category': category,
      'date_taken': dateTaken,
    };
  }
}