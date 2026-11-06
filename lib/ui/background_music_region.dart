import 'dart:async';

import 'package:flutter/material.dart';

import '../services/background_music_service.dart';
import 'app_shell.dart';

class BackgroundMusicRegion extends StatefulWidget {
  final BackgroundMusicTrack? track;
  final Widget child;
  final bool showToggle;
  final Alignment toggleAlignment;
  final EdgeInsets toggleMargin;

  const BackgroundMusicRegion({
    super.key,
    required this.track,
    required this.child,
    this.showToggle = true,
    this.toggleAlignment = Alignment.bottomRight,
    this.toggleMargin = const EdgeInsets.only(right: 14, bottom: 14),
  });

  @override
  State<BackgroundMusicRegion> createState() => _BackgroundMusicRegionState();
}

class _BackgroundMusicRegionState extends State<BackgroundMusicRegion>
    with RouteAware {
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    unawaited(BackgroundMusicService.instance.ensureInitialized());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _activate();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant BackgroundMusicRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) _activate();
  }

  @override
  void didPush() => _activate();

  @override
  void didPushNext() {}

  @override
  void didPopNext() => _activate();

  void _activate() {
    final track = widget.track;
    if (track == null) {
      unawaited(BackgroundMusicService.instance.pause());
    } else {
      unawaited(BackgroundMusicService.instance.play(track));
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MusicToggleButton extends StatefulWidget {
  const MusicToggleButton({super.key});

  @override
  State<MusicToggleButton> createState() => _MusicToggleButtonState();
}

class _MusicToggleButtonState extends State<MusicToggleButton> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        BackgroundMusicService.instance,
        SignVoiceMuteControl.instance,
      ]),
      builder: (context, _) {
        final service = BackgroundMusicService.instance;
        final voice = SignVoiceMuteControl.instance;
        return Semantics(
          button: true,
          label: voice.active
              ? (voice.muted ? 'Unmute voice' : 'Mute voice')
              : (service.muted ? 'Play music' : 'Mute music'),
          child: Material(
            color: Colors.white.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            elevation: 5,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: voice.active ? voice.toggleVoice : service.toggleMuted,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  (voice.active ? voice.muted : service.muted)
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: kDeepBlue,
                  size: 25,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets the app-wide bottom speaker control toggle sign-result speech while
/// the sign detector is the active route; elsewhere it controls background music.
class SignVoiceMuteControl extends ChangeNotifier {
  SignVoiceMuteControl._();

  static final SignVoiceMuteControl instance = SignVoiceMuteControl._();

  bool muted = false;
  VoidCallback? _toggle;
  bool get active => _toggle != null;

  void attach({required bool initialMuted, required VoidCallback toggle}) {
    muted = initialMuted;
    _toggle = toggle;
    notifyListeners();
  }

  void detach() {
    _toggle = null;
    notifyListeners();
  }

  void setMuted(bool value) {
    if (muted == value) return;
    muted = value;
    notifyListeners();
  }

  void toggleVoice() => _toggle?.call();
}
