import 'package:flutter/material.dart';
import 'custom_appbar_clipper.dart';

class CustomCurvedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading; // ← Add this

  const CustomCurvedAppBar({
    super.key,
    required this.title,
    this.leading, // ← Add this
  });

  @override
  Size get preferredSize => Size.fromHeight(150);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: CustomAppBarClipper(),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent,
                  Colors.lightBlueAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 40,
          child: leading ??
              IconButton( // ← Use `leading` if provided
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
        ),
        Positioned.fill(
          top: 40,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        )
      ],
    );
  }
}
