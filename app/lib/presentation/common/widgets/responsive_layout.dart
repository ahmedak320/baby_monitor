import 'package:flutter/material.dart';

import '../../../utils/platform_info.dart';

/// Responsive layout builder for phone, tablet, and TV.
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? tv;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.tv,
  });

  static const tabletBreakpoint = 600.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isTV && tv != null) {
      return tv!;
    }
    if (isTablet(context) && tablet != null) {
      return tablet!;
    }
    return phone;
  }
}

/// Adaptive grid column count based on screen width.
int adaptiveGridColumns(BuildContext context, {int phoneColumns = 2}) {
  final width = MediaQuery.sizeOf(context).width;
  if (PlatformInfo.isTV) return phoneColumns + 3; // TV: more columns
  if (width >= 1200) return phoneColumns + 2;
  if (width >= 900) return phoneColumns + 1;
  if (width >= 600) return phoneColumns + 1;
  return phoneColumns;
}
