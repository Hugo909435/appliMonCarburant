class Department {
  const Department({
    required this.num,
    required this.name,
    required this.region,
    required this.regionSlug,
  });

  final String num;
  final String name;
  final String region;
  final String regionSlug;

  factory Department.fromJson(String number, Map<String, dynamic> json) => Department(
        num: number,
        name: json['name'] as String,
        region: json['region'] as String,
        regionSlug: json['regionSlug'] as String,
      );
}
