import 'package:doorbot_fyp/views/history_view.dart';
import 'package:doorbot_fyp/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

import '../viewmodels/home_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/custom_curved_appbar.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(),
      child: Consumer2<HomeViewModel, AuthViewModel>(
        builder: (context, homeVM, authVM, _) {
          return Scaffold(
            appBar: CustomCurvedAppBar(title: "Front Door"),
            drawer: Drawer(
              child: Column(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(
                      authVM.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    accountEmail: Text(authVM.email),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Colors.blueAccent,
                        size: 40,
                      ),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent, Colors.lightBlueAccent],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.history, color: Colors.blueAccent),
                    title: Text("History"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HistoryView()),
                      );
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.notifications,
                      color: Colors.blueAccent,
                    ),
                    title: Text("Notifications"),
                    value: homeVM.notificationsOn,
                    onChanged: (val) {
                      homeVM.toggleNotifications();
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final isDark =
                          AdaptiveTheme.of(context).mode ==
                          AdaptiveThemeMode.dark;
                      return SwitchListTile(
                        secondary: Icon(
                          Icons.nightlight_round,
                          color: Colors.blueAccent,
                        ),
                        title: Text("Dark Theme"),
                        value: isDark,
                        onChanged: (val) {
                          if (val) {
                            AdaptiveTheme.of(context).setDark();
                          } else {
                            AdaptiveTheme.of(context).setLight();
                          }
                        },
                      );
                    },
                  ),
                  Spacer(),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text("Logout", style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await authVM.logout();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => LoginView()),
                      );
                    },
                  ),
                ],
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 16),
                  _buildVideoPreview(),
                  SizedBox(height: 100),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        activeIcon: Icons.mic,
                        inactiveIcon: Icons.mic_off,
                        activeLabel: "Microphone",
                        inactiveLabel: "Microphone",
                        active: homeVM.microphoneOn,
                        onTap: homeVM.toggleMicrophone,
                      ),
                      _buildControlButton(
                        activeIcon: Icons.volume_up,
                        inactiveIcon: Icons.volume_off,
                        activeLabel: "Speaker",
                        inactiveLabel: "Speaker",
                        active: homeVM.speakerOn,
                        onTap: homeVM.toggleSpeaker,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        Container(width: double.infinity, height: 220, color: Colors.black),
        Positioned.fill(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(100),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, size: 64, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "LIVE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String activeLabel,
    required String inactiveLabel,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : inactiveIcon,
              color: active ? Colors.white : Colors.blueGrey,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              active ? activeLabel : inactiveLabel,
              style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
