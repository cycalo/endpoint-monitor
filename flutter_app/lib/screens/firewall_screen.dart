import 'package:flutter/material.dart';

import '../widgets/em_brand_app_bar.dart';

class FirewallScreen extends StatelessWidget {
  const FirewallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Active EM_ firewall rules are managed on the endpoint. Use Network to block/unblock IPs; isolation is on the Dashboard.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ),
      ),
    );
  }
}
