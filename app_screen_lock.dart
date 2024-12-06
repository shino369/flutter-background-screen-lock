import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

enum AppScreenLockConstants { success, cancelled, failure, logout }

/// ロック画面のコントローラー
class AppScreenLockController {
  /// ロック画面を解除した際のコールバック
  final void Function([AppScreenLockConstants? args]) didUnlock;

  /// ロック画面を表示する
  final Future<dynamic> Function() showLockScreen;

  /// ロック画面を有効にする
  final void Function() enable;

  /// ロック画面を無効にする
  final void Function() disable;

  /// バックグラウンドロックの遅延時間を設定する
  final void Function(Duration latency) setBackgroundLockLatency;

  /// ロック画面閉じた際に渡す引数
  final Object? launchArg;

  /// ロック画面が有効かどうか
  final bool enabled;

  /// ロック中かどうか
  final bool isLocked;

  /// ロック画面をキャンセル可能かどうか
  final bool canBeCancelled;

  /// ロック画面をキャンセル可能かどうかを設定する
  final void Function(bool value) setCanBeCancelled;

  /// ログイン画面かどうか
  final bool isLogin;

  /// ログイン画面かどうかを設定する
  final void Function(bool value) setIsLogin;

  AppScreenLockController({
    required this.didUnlock,
    required this.showLockScreen,
    required this.enable,
    required this.disable,
    required this.setBackgroundLockLatency,
    required this.launchArg,
    required this.enabled,
    required this.isLocked,
    required this.canBeCancelled,
    required this.setCanBeCancelled,
    required this.isLogin,
    required this.setIsLogin,
  });
}

/// ロック画面のコントローラーを提供する
class AppScreenLockControllerProvider extends InheritedWidget {
  final AppScreenLockController controller;

  const AppScreenLockControllerProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static AppScreenLockController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppScreenLockControllerProvider>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AppScreenLockControllerProvider oldWidget) => false;
}

/// AppScreenLock
/// アプリのライフサイクルを監視し、ロック画面を表示する
class AppScreenLock extends HookWidget {
  ///  メイン画面のビルダー
  final Widget Function(BuildContext context, Object? launchArg) builder;

  /// ロック画面のビルダー
  final WidgetBuilder? lockScreenBuilder;

  /// 非アクティブ画面のビルダー
  final WidgetBuilder? inactiveBuilder;

  /// ロック画面を初期表示するかどうか
  final bool initiallyEnabled;

  /// バックグラウンドロックの遅延時間
  final Duration initialBackgroundLockLatency;

  /// 画面遷移のアニメビルダー
  final Widget Function(
    BuildContext,
    Animation<double>,
    Animation<double>,
    Widget,
  )? transitionsBuilder;

  /// 画面遷移の時間
  final Duration transitionDuration;

  const AppScreenLock({
    super.key,
    required this.builder,
    this.lockScreenBuilder,
    this.inactiveBuilder,
    this.initiallyEnabled = true,
    this.initialBackgroundLockLatency = Duration.zero,
    this.transitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final locked = useState(initiallyEnabled);
    final enabled = useState(initiallyEnabled);
    final inactive = useState(false);
    final didUnlockForAppLaunch = useState(!initiallyEnabled);
    final backgroundLockLatency = useState(initialBackgroundLockLatency);
    final launchArg = useState<Object?>(null);
    final didUnlockCompleter = useRef<Completer?>(null);
    final canBeCancelled = useState(true);
    final isLogin = useState(false);

    Future<dynamic> showLockScreen() async {
      didUnlockCompleter.value ??= Completer();
      if (!locked.value) locked.value = true;

      return didUnlockCompleter.value!.future;
    }

    void setEnabled(bool isEnabled) => enabled.value = isEnabled;

    void enable() => setEnabled(true);

    void disable() => setEnabled(false);

    void setBackgroundLockLatency(Duration latency) =>
        backgroundLockLatency.value = latency;

    void didUnlockOnAppPaused() => locked.value = false;

    void didUnlockOnAppLaunch(Object? args) {
      launchArg.value = args;
      didUnlockForAppLaunch.value = true;
      locked.value = false;
    }

    void didUnlock([Object? args]) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (didUnlockForAppLaunch.value) {
          didUnlockOnAppPaused();
        } else {
          didUnlockOnAppLaunch(args);
        }

        if (didUnlockCompleter.value != null &&
            !didUnlockCompleter.value!.isCompleted) {
          didUnlockCompleter.value?.complete(args);
          didUnlockCompleter.value = null;
        }
      });
    }

    void setCanBeCancelled(bool value) => canBeCancelled.value = value;

    void setIsLogin(bool value) => isLogin.value = value;

    _useAppLifecycle(
      enabled,
      locked,
      backgroundLockLatency,
      showLockScreen,
      inactive,
      canBeCancelled,
      inactiveBuilder,
    );

    final controller = AppScreenLockController(
      didUnlock: didUnlock,
      showLockScreen: showLockScreen,
      enable: enable,
      disable: disable,
      setBackgroundLockLatency: setBackgroundLockLatency,
      launchArg: launchArg.value,
      enabled: enabled.value,
      isLocked: locked.value,
      canBeCancelled: canBeCancelled.value,
      setCanBeCancelled: setCanBeCancelled,
      isLogin: isLogin.value,
      setIsLogin: setIsLogin,
    );

    return AppScreenLockControllerProvider(
      controller: controller,
      child: Navigator(
        onPopPage: (route, result) => route.didPop(result),
        pages: [
          if (didUnlockForAppLaunch.value)
            MaterialPage(
              key: const ValueKey('MainScreen'),
              child: builder(context, launchArg.value),
            ),
          if (locked.value)
            transitionsBuilder != null
                ? _AnimatedPage(
                    key: const ValueKey('LockScreen'),
                    transitionsBuilder: transitionsBuilder!,
                    transitionDuration: transitionDuration,
                    child: lockScreenBuilder != null
                        ? lockScreenBuilder!(context)
                        : Container(),
                  )
                : _NoAnimationPage(
                    key: const ValueKey('LockScreen'),
                    child: lockScreenBuilder != null
                        ? lockScreenBuilder!(context)
                        : Container(),
                  )
          else if (inactive.value && inactiveBuilder != null)
            _NoAnimationPage(
              key: const ValueKey('InactiveScreen'),
              child: inactiveBuilder!(context),
            ),
        ],
      ),
    );
  }
}

/// アプリのライフサイクルを監視し、ロック画面を表示する
void _useAppLifecycle(
  ValueNotifier<bool> enabled,
  ValueNotifier<bool> locked,
  ValueNotifier<Duration> backgroundLockLatency,
  VoidCallback showLockScreen,
  ValueNotifier<bool> inactive,
  ValueNotifier<bool> canBeCancelled,
  WidgetBuilder? inactiveBuilder,
) {
  // Use a ref to manage the Timer across rebuilds
  final timeRef = useRef<DateTime?>(null);

  // Memoize the handleLifecycleChange callback
  final handleLifecycleChange = useCallback(
    (AppLifecycleState state) {
      if (!enabled.value) return;

      // 元々のロジックはTimerを使っていたが、Timerはアプリがバックグラウンドになると停止するため、
      // アプリがバックグラウンドになった際に時間を記録しておき、アプリがフォアグラウンドになった際に
      // 時間差を計算してロック画面を表示するように変更
      if (state == AppLifecycleState.paused && !locked.value) {
        timeRef.value = DateTime.now();
      }

      if (state == AppLifecycleState.resumed && timeRef.value != null) {
        final currentTime = DateTime.now();
        final diff = currentTime.difference(timeRef.value!);
        if (diff.inSeconds > backgroundLockLatency.value.inSeconds) {
          canBeCancelled.value = false;
          timeRef.value = null;
          showLockScreen();
        }
      }

      // 注意：inactive は使わないでください
      // auto-fillなどの提示が出る時もinactiveになるため、バグが発生するので使い物にならない
      if (inactiveBuilder != null) {
        inactive.value = state == AppLifecycleState.inactive;
      }
    },
    [
      enabled.value,
      locked.value,
      backgroundLockLatency.value,
      showLockScreen,
      inactive.value,
      inactiveBuilder,
      timeRef.value,
    ],
  );

  useEffect(() {
    final observer = _LifecycleListener(handleLifecycleChange);
    WidgetsBinding.instance.addObserver(observer);

    // Cleanup on unmount
    return () {
      WidgetsBinding.instance.removeObserver(observer);
    };
  }, [handleLifecycleChange]);
}

//===============================================================
// 以下コピペ
//===============================================================

class _LifecycleListener extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onChange;

  _LifecycleListener(this.onChange);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onChange(state);
  }
}

class _NoAnimationPage<T> extends Page<T> {
  const _NoAnimationPage({
    required this.child,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final bool maintainState;
  final bool fullscreenDialog;
  final bool allowSnapshotting;

  @override
  Route<T> createRoute(BuildContext context) => _NoAnimationPageRoute<T>(
      page: this, allowSnapshotting: allowSnapshotting);
}

class _NoAnimationPageRoute<T> extends PageRoute<T> {
  _NoAnimationPageRoute({
    required _NoAnimationPage<T> page,
    super.allowSnapshotting,
  }) : super(settings: page) {
    assert(opaque);
  }

  _NoAnimationPage<T> get _page => settings as _NoAnimationPage<T>;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      _page.child;

  @override
  Duration get transitionDuration => Duration.zero;
}

class _AnimatedPage<T> extends Page<T> {
  final Widget child;
  final Duration transitionDuration;
  final Widget Function(
    BuildContext,
    Animation<double>,
    Animation<double>,
    Widget,
  ) transitionsBuilder;

  const _AnimatedPage({
    required this.child,
    required this.transitionDuration,
    required this.transitionsBuilder,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: transitionDuration,
      transitionsBuilder: transitionsBuilder,
    );
  }
}
