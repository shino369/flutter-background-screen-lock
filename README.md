# flutter-background-screen-lock
Show your custom lock screen after coming back from background, or use the lock screen as a route guarding page.\
Initially designed for high security app like banking app.

---
Hook version of [flutter app lock](https://github.com/tomalabaster/flutter_app_lock).\
You may feel more familiar if you like React.

Fixed some bugs and added enhanced features like:
- IOS background Timer not running in background issue
- Accepting  `transitionDuration` and `transitionsBuilder` in constructor
- Refactored into a more convenient way of async status return after closing the lock page

Please add [flutter hook](https://pub.dev/packages/flutter_hooks) package to use it.

(Recently no time to make it a package, maybe later.)

---


```dart
MaterialApp(
  ...
  builder: (context, child) => AppScreenLock(
      builder: (context, arg) => child ?? const SizedBox.shrink(),
      lockScreenBuilder: (context) => const lockPage(),
      initiallyEnabled: false,
      initialBackgroundLockLatency: const Duration(milliseconds: 300),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: ..., // your transition builder
      inactiveBuilder: (context) => const inactivePage(),
  ),
);
```

For example you can use it as route guarding:
```dart
// before going to a specific route, insde a async click callback
final controller = AppScreenLockControllerProvider.of(context);
final result = await controller?.showLockScreen();
if(result != AppScreenLockConstants.success) return;
Navigator.push(context, ...);
```

Inside the lock screen:
```dart
final controller = AppScreenLockControllerProvider.of(context);
controller.didUnlock(AppScreenLockConstants.success);
```

For the status here I simply set to enum of `success, cancelled, failure, logout`, pretty straightforward. It can be changed it to other object if you want.\
You can implement a more robust route guarding feature by using [GoRouter](https://pub.dev/packages/go_router) redirect feature, or simple create a wrapper function for navigator.
