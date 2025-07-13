// lib/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                      // Navigate to history
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(Icons.notifications, color: Colors.blueAccent),
                    title: Text("Notifications"),
                    value: true,
                    onChanged: (val) {},
                  ),
                  SwitchListTile(
                    secondary: Icon(Icons.nightlight_round, color: Colors.blueAccent),
                    title: Text("Dark Theme"),
                    value: false,
                    onChanged: (val) {},
                  ),
                  Spacer(),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      "Logout",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await authVM.logout();
                      Navigator.of(context).pushReplacementNamed("/login");
                    },
                  ),
                ],
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 16),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    child: Image.asset(
                      "assets/doorbell.png",
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: Icons.mic,
                        label: "Microphone",
                        active: homeVM.microphoneOn,
                        onTap: homeVM.toggleMicrophone,
                      ),
                      _buildControlButton(
                        icon: Icons.volume_up,
                        label: "Speaker",
                        active: homeVM.speakerOn,
                        onTap: homeVM.toggleSpeaker,
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
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
              icon,
              color: active ? Colors.white : Colors.blueGrey,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }
}
