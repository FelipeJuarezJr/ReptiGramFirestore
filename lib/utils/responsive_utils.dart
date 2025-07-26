import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints for responsive design
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1600;

  // Screen size helpers
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  // Responsive sizing helpers
  static double getResponsiveWidth(BuildContext context, {
    double mobile = 1.0,
    double tablet = 0.8,
    double desktop = 0.6,
    double largeDesktop = 0.5,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    double multiplier;

    if (screenWidth >= largeDesktopBreakpoint) {
      multiplier = largeDesktop;
    } else if (screenWidth >= desktopBreakpoint) {
      multiplier = desktop;
    } else if (screenWidth >= tabletBreakpoint) {
      multiplier = tablet;
    } else {
      multiplier = mobile;
    }

    return screenWidth * multiplier;
  }

  static double getResponsivePadding(BuildContext context, {
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
    double largeDesktop = 48.0,
  }) {
    if (isLargeDesktop(context)) return largeDesktop;
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static double getResponsiveFontSize(BuildContext context, {
    double mobile = 14.0,
    double tablet = 16.0,
    double desktop = 18.0,
    double largeDesktop = 20.0,
  }) {
    if (isLargeDesktop(context)) return largeDesktop;
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Grid layout helpers
  static int getResponsiveGridCrossAxisCount(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int largeDesktop = 4,
  }) {
    if (isLargeDesktop(context)) return largeDesktop;
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static double getResponsiveGridChildAspectRatio(BuildContext context, {
    double mobile = 1.0,
    double tablet = 1.2,
    double desktop = 1.4,
    double largeDesktop = 1.6,
  }) {
    if (isLargeDesktop(context)) return largeDesktop;
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Container sizing helpers
  static double getMaxContentWidth(BuildContext context) {
    if (isLargeDesktop(context)) return 1400;
    if (isDesktop(context)) return 1200;
    if (isTablet(context)) return 900;
    return MediaQuery.of(context).size.width;
  }

  static EdgeInsets getResponsiveEdgeInsets(BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
    EdgeInsets? largeDesktop,
  }) {
    mobile ??= const EdgeInsets.all(16.0);
    tablet ??= const EdgeInsets.all(24.0);
    desktop ??= const EdgeInsets.all(32.0);
    largeDesktop ??= const EdgeInsets.all(48.0);

    if (isLargeDesktop(context)) return largeDesktop;
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Layout helpers
  static Widget responsiveWrapper({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    final maxContentWidth = maxWidth ?? getMaxContentWidth(context);
    final responsivePadding = padding ?? getResponsiveEdgeInsets(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: responsivePadding,
          child: child,
        ),
      ),
    );
  }

  // Sidebar layout helper
  static Widget sidebarLayout({
    required BuildContext context,
    required Widget sidebar,
    required Widget mainContent,
    double sidebarWidth = 280,
    double sidebarWidthLarge = 320,
  }) {
    if (!isWideScreen(context)) {
      return mainContent;
    }

    final actualSidebarWidth = isLargeDesktop(context) ? sidebarWidthLarge : sidebarWidth;

    return Row(
      children: [
        SizedBox(
          width: actualSidebarWidth,
          child: sidebar,
        ),
        Expanded(
          child: mainContent,
        ),
      ],
    );
  }

  // Card layout helpers
  static Widget responsiveCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
    double? elevation,
  }) {
    final responsivePadding = padding ?? getResponsiveEdgeInsets(
      context,
      mobile: const EdgeInsets.all(16.0),
      tablet: const EdgeInsets.all(20.0),
      desktop: const EdgeInsets.all(24.0),
      largeDesktop: const EdgeInsets.all(32.0),
    );

    final responsiveElevation = elevation ?? (isWideScreen(context) ? 4.0 : 2.0);

    return Card(
      elevation: responsiveElevation,
      child: Padding(
        padding: responsivePadding,
        child: child,
      ),
    );
  }
} 