import 'package:flutter/material.dart';
import 'package:minsk8/import.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final child = Center(
      child: Text('xxx'),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      drawer: MainDrawer('/login'),
      body: ScrollBody(child: child),
    );
  }
}
