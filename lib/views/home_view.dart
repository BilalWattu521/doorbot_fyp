import 'package:doorbot_fyp/views/history_view.dart';

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
                      // No need to navigate manually, AuthWrapper handles it
                    },
                  ),
                ],
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 16),
                  _buildVideoPreview(homeVM),
                  SizedBox(height: 30),
                  _buildDoorStatus(homeVM),
                  SizedBox(height: 30),
                  IgnorePointer(
                    ignoring: !homeVM.canUnlock,
                    child: GestureDetector(
                      onTapDown: (_) => homeVM.onUnlockPressed(),
                      onTapUp: (_) => homeVM.onUnlockReleased(),
                      onTapCancel: () => homeVM.onUnlockReleased(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: !homeVM.canUnlock
                              ? Colors.grey.shade400
                              : homeVM.unlockPressed
                              ? Colors.green
                              : Colors.white,
                          borderRadius: BorderRadius.circular(80), // Circular
                          border: Border.all(
                            color: !homeVM.canUnlock
                                ? Colors.grey
                                : Colors.green,
                            width: homeVM.unlockPressed ? 0 : 4,
                          ),
                          boxShadow: [
                            if (homeVM.unlockPressed && homeVM.canUnlock)
                              BoxShadow(
                                color: Colors.green.withAlpha(150),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            else
                              BoxShadow(
                                color: Colors.grey.withAlpha(50),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !homeVM.canUnlock
                                  ? Icons.timer_outlined
                                  : homeVM.unlockPressed
                                  ? Icons.lock_open
                                  : Icons.lock_outline,
                              color: !homeVM.canUnlock
                                  ? Colors.white
                                  : homeVM.unlockPressed
                                  ? Colors.white
                                  : Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              !homeVM.canUnlock
                                  ? "PLEASE\nWAIT"
                                  : homeVM.unlockPressed
                                  ? "UNLOCKING"
                                  : "TAP TO\nUNLOCK",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !homeVM.canUnlock
                                    ? Colors.white
                                    : homeVM.unlockPressed
                                    ? Colors.white
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

  Widget _buildVideoPreview(HomeViewModel homeVM) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: homeVM.isStreaming && homeVM.currentFrame != null
                ? Image.memory(
                    homeVM.currentFrame!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Container(
                    width: double.infinity,
                    height: 220,
                    color: Colors.grey[900],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off, color: Colors.grey, size: 48),
                        SizedBox(height: 8),
                        Text(
                          "Waiting for camera...",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
          // LIVE indicator
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: homeVM.isStreaming ? Colors.red : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (homeVM.isStreaming)
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    homeVM.isStreaming ? "LIVE" : "OFFLINE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorStatus(HomeViewModel homeVM) {
    final data = homeVM.doorStatus;
    final isLoading = data == null;
    final status = data?['status'] ?? 'unknown';
    final isLocked = status == 'locked';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLocked ? Colors.red.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isLocked ? Colors.red : Colors.green,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isLocked ? Icons.lock : Icons.lock_open,
                color: isLocked ? Colors.red : Colors.green,
                size: 28,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Door Status',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    isLoading
                        ? 'Loading...'
                        : isLocked
                        ? 'Locked'
                        : 'Unlocked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLocked ? Colors.red : Colors.green,
              ),
            ),
        ],
      ),
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
