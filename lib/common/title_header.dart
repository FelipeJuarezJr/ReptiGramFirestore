import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../screens/login_screen.dart';
import '../widgets/nav_drawer.dart';
import '../state/app_state.dart';
import '../utils/responsive_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TitleHeader extends StatelessWidget {
  const TitleHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appState = Provider.of<AppState>(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: AppColors.titleText,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black54,
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutSine,
                      )),
                      child: Dialog(
                        insetPadding: const EdgeInsets.only(left: 0),
                        alignment: Alignment.centerLeft,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: ResponsiveUtils.isWideScreen(context) ? 560 : 280),
                          child: Container(
                            width: ResponsiveUtils.isWideScreen(context) ? 560 : 280,
                            child: NavDrawer(
                              userEmail: user?.email,
                              userName: user?.displayName ?? 'User', // Fallback, NavDrawer will use AppState
                              userPhotoUrl: user?.photoURL,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const Expanded(
            child: Center(
              child: Text(
                'ReptiGram',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.logoTitleText,
                  shadows: [
                    Shadow(
                      color: AppColors.titleShadow,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          // TODO: Just uncomment this when you want to add a logout button
          // Padding(
          //   padding: const EdgeInsets.only(right: 16.0),
          //   child: IconButton(
          //     icon: const Icon(
          //       Icons.logout,
          //       color: AppColors.titleText,
          //     ),
          //     onPressed: () {
          //       FirebaseAuth.instance.signOut();
          //       Navigator.pushAndRemoveUntil(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => const LoginScreen(),
          //         ),
          //         (route) => false,
          //       );
          //     },
          //   ),
          // ),
        ],
      ),
    );
  }
} 