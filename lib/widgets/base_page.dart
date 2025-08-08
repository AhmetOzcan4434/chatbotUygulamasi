import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'drawer.dart';

class BasePage extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showDrawer;
  final Function(bool)? onDrawerChanged;

  const BasePage({
    super.key,
    required this.title,
    required this.body,
    this.showDrawer = true,
    this.onDrawerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: title),
      drawer: showDrawer ? const DrawerMenu() : null,
      body: Center(child: body),
      onDrawerChanged: onDrawerChanged,
    );
  }
}
