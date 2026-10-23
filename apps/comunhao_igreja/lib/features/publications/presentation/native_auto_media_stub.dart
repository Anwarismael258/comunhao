import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant NativeAutoMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.kind != widget.kind) {
      _disposeController();
      _setupController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _setupController() {
    if (widget.kind != NativeAutoMediaKind.video) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) {
      controller.setLooping(false);
      if (mounted) setState(() {});
    });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == NativeAutoMediaKind.audio) {
      return _AudioPlaceholder(height: widget.height);
    }
    final controller = _controller;
    final initializeFuture = _initializeFuture;
    if (controller == null || initializeFuture == null) {
      return _VideoShell(
        height: widget.height,
        child: const Icon(Icons.play_circle_fill, size: 36),
      );
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _VideoShell(
            height: widget.height,
            child: const CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || controller.value.hasError) {
          return _VideoShell(
            height: widget.height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Não foi possível abrir este vídeo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        final aspectRatio = controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                _VideoControls(
                  controller: controller,
                  onFullscreen: widget.onVideoFullscreen,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    this.onFullscreen,
  });

  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final playing = controller.value.isPlaying;
          return Stack(
            children: [
              if (!playing)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 28,
                      color: Colors.white,
                      onPressed: () {
                        controller.play();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        onPressed: () {
                          playing ? controller.pause() : controller.play();
                        },
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      if (onFullscreen != null)
                        IconButton(
                          color: Colors.white,
                          onPressed: onFullscreen,
                          icon: const Icon(Icons.fullscreen),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VideoShell extends StatelessWidget {
  const _VideoShell({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _AudioPlaceholder extends StatelessWidget {
  const _AudioPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.graphic_eq_rounded, size: 34),
    );
  }
}
