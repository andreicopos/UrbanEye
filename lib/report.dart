class Report {
  final int id;
  final int userId;
  final String userName;
  final List<String> issues;
  final String details;
  final String location;
  final String? imagePath;   // nullable now!
  final String status;
  final DateTime createdAt;
  final int likes;

  Report({
    required this.id,
    required this.userId,
    required this.userName,
    required this.issues,
    required this.details,
    required this.location,
    this.imagePath,          // no longer required
    required this.status,
    required this.likes,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    id:        j['id'],
    userId:    j['user_id'],
    userName:  j['user_name'],
    issues:    List<String>.from(j['issues']),
    details:   j['details'],
    location:  j['location'],
    imagePath: (j['image_path'] as String? ?? '').startsWith('/')
  ? j['image_path']
  : '/' + (j['image_path'] as String? ?? ''),
    status:    j['status'] as String,
    likes:     j['likes'] as int,
    createdAt: DateTime.parse(j['created_at']),
  );
}