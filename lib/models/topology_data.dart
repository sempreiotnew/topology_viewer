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

  factory TopologyData.fromJson(Map<String, dynamic> json) => TopologyData(
        seq: json['seq'] as int,
        root: json['root'] as String,
        delivered: json['delivered'] as bool,
        acked: json['acked'] as int,
        total: json['total'] as int,
        retries: json['retries'] as int,
        nodes: (json['nodes'] as List<dynamic>)
            .map((n) => MeshNode.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}
