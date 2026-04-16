import 'package:flutter/material.dart';

class DataPulse {
  final String fromMac;
  final String toMac;
  final AnimationController controller;
  final Animation<double> progress;

  DataPulse({
    required this.fromMac,
    required this.toMac,
    required this.controller,
    required this.progress,
  });
}
