// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

enum NativeAutoMediaKind { video, audio }

class NativeAutoMedia extends StatefulWidget {
  const NativeAutoMedia({
    required this.url,
    required this.kind,
    required this.height,
    required this.viewKey,
    this.onVideoFullscreen,
    super.key,
  });

  final String url;
  final NativeAutoMediaKind kind;
  final double height;
  final String viewKey;
  final VoidCallback? onVideoFullscreen;

  @override
  State<NativeAutoMedia> createState() => _NativeAutoMediaState();
}

class _NativeAutoMediaState extends State<NativeAutoMedia> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'comunhao-igreja-media-${widget.kind.name}-${widget.viewKey}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return switch (widget.kind) {
        NativeAutoMediaKind.video => _buildVideo(),
        NativeAutoMediaKind.audio => _buildAudio(),
      };
    });
  }

  html.Element _buildVideo() {
    final video = html.VideoElement()
      ..src = widget.url
      ..autoplay = false
      ..muted = false
      ..loop = false
      ..controls = true;
    video
      ..setAttribute('preload', 'auto')
      ..setAttribute('crossorigin', 'anonymous')
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = 'black'
      ..style.borderRadius = '8px';
    return video;
  }

  html.Element _buildAudio() {
    final container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'relative'
      ..style.borderRadius = '8px'
      ..style.background = '#eef4f2';
    final audio = html.AudioElement()
      ..src = widget.url
      ..loop = false
      ..controls = true;
    audio
      ..setAttribute('preload', 'auto')
      ..setAttribute('crossorigin', 'anonymous')
      ..style.width = '92%'
      ..style.position = 'absolute'
      ..style.left = '4%'
      ..style.top = '50%'
      ..style.transform = 'translateY(-50%)';
    container.children.add(audio);
    return container;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.kind == NativeAutoMediaKind.video
          ? widget.onVideoFullscreen
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
