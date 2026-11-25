import 'package:flutter/material.dart';

class EkycFlowScaffold extends StatelessWidget {
  const EkycFlowScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.error,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final String? error;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(subtitle!,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          if (error != null)
            Material(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
