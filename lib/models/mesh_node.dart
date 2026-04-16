class MeshNode {
  final String mac;
  final int layer;
  final String parent;
  final int? rssi;
  final bool acked;
  final bool missing;

  const MeshNode({
    required this.mac,
    required this.layer,
    required this.parent,
    required this.rssi,
    required this.acked,
    required this.missing,
  });

  factory MeshNode.fromJson(Map<String, dynamic> json) => MeshNode(
        mac: json['mac'] as String,
        layer: json['layer'] as int,
        parent: json['parent'] as String,
        rssi: json['rssi'] as int?,
        acked: json['acked'] as bool,
        missing: json['missing'] as bool? ?? false,
      );

  String get shortMac {
    final parts = mac.split(':');
    return parts.length >= 2
        ? '${parts[parts.length - 2]}:${parts.last}'.toUpperCase()
        : mac;
  }
}
