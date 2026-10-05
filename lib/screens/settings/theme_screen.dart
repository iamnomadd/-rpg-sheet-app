import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/app_state.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<AppState>().themeId;
    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: appThemes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final preset = appThemes[index];
          final active = preset.id == selected;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: preset.seed,
                foregroundColor: preset.seed.computeLuminance() > 0.55 ? Colors.black : Colors.white,
                child: Icon(preset.icon),
              ),
              title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(preset.description),
              trailing: active ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : const Icon(Icons.chevron_right),
              onTap: () => context.read<AppState>().setTheme(preset.id),
            ),
          );
        },
      ),
    );
  }
}
