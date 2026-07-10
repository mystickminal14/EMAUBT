import 'package:flutter/material.dart';

/// Shared breakpoints used across the app to keep mobile, tablet and
/// desktop/web layouts consistent.
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

enum DeviceType { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  DeviceType get deviceType {
    final width = screenWidth;
    if (width >= Breakpoints.tablet) return DeviceType.desktop;
    if (width >= Breakpoints.mobile) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Pick a grid column count based on the current viewport width.
  int gridColumns({int mobile = 2, int tablet = 3, int desktop = 4}) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Cap content width on larger screens so pages don't stretch edge to edge.
  double responsiveMaxWidth({double tablet = 720, double desktop = 1100}) {
    switch (deviceType) {
      case DeviceType.mobile:
        return double.infinity;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Horizontal page padding that grows slightly on larger viewports.
  double responsiveHorizontalPadding({
    double mobile = 16,
    double tablet = 32,
    double desktop = 48,
  }) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}

/// Wraps [child] so it stays full-width on phones but gets centered with a
/// capped max width on tablets/desktop/web, avoiding overly stretched
/// layouts on large viewports. Behavior on mobile is unchanged.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double tabletMaxWidth;
  final double desktopMaxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.tabletMaxWidth = 720,
    this.desktopMaxWidth = 1100,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (context.isMobile) {
      return content;
    }

    final maxWidth = context.isDesktop ? desktopMaxWidth : tabletMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
