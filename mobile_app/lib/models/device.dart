class Device {
  final String id;
  final String name;
  final String address;
  final int port;
  final String platform;
  final String version;
  final String? alias;
  final bool trusted;
  final DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.platform,
    required this.version,
    this.alias,
    this.trusted = false,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get displayName => alias ?? name;

  Device copyWith({
    String? name,
    String? address,
    int? port,
    String? alias,
    bool? trusted,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      platform: platform,
      version: version,
      alias: alias ?? this.alias,
      trusted: trusted ?? this.trusted,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'platform': platform,
      'version': version,
      'alias': alias,
      'trusted': trusted,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      port: json['port'],
      platform: json['platform'],
      version: json['version'],
      alias: json['alias'],
      trusted: json['trusted'] ?? false,
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }
}
