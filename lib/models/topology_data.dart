import 'mesh_node.dart';

class TopologyData {
  final int seq;
  final String root;
  final bool delivered;
  final int acked;
  final int total;
  final int retries;
  final List<MeshNode> nodes;

  const TopologyData({
    required this.seq,
    required this.root,
    required this.delivered,
    required this.acked,
    required this.total,
    required this.retries,
    required this.nodes,
  });

  factory TopologyData.fromJson(Map<String, dynamic> json) {
    final nodes = (json['nodes'] as List<dynamic>)
        .map((n) => MeshNode.fromJson(n as Map<String, dynamic>))
        .toList();

    // Serial format has an explicit "root" MAC.
    // MQTT format has no "root" — derive it as the node with the smallest
    // non-zero layer value; if all are 0 or list is empty, fall back to the
    // first node's MAC so the renderer always has something to start from.
    String root = (json['root'] as String?) ?? '';
    if (root.isEmpty && nodes.isNotEmpty) {
      final nonZero = nodes.where((n) => n.layer > 0);
      root = nonZero.isNotEmpty
          ? nonZero.reduce((a, b) => a.layer < b.layer ? a : b).mac
          : nodes.first.mac;
    }

    return TopologyData(
      seq: json['seq'] as int,
      root: root,
      // Optional top-level fields that MQTT format omits
      delivered: (json['delivered'] as bool?) ?? true,
      acked: (json['acked'] as int?) ?? nodes.where((n) => n.acked).length,
      total: (json['total'] as int?) ?? nodes.length,
      retries: (json['retries'] as int?) ?? 0,
      nodes: nodes,
    );
  }
}
