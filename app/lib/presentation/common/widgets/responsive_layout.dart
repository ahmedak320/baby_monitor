import 'package:flutter/material.dart';

/// Responsive layout builder for phone vs tablet.
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
  });

  static const tabletBreakpoint = 600.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    if (isTablet(context) && tablet != null) {
      return tablet!;
    }
    return phone;
  }
}

/// Adaptive grid column count based on screen width.
int adaptiveGridColumns(BuildContext context, {int phoneColumns = 2}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1200) return phoneColumns + 2;
  if (width >= 900) return phoneColumns + 1;
  if (width >= 600) return phoneColumns + 1;
  return phoneColumns;
}
