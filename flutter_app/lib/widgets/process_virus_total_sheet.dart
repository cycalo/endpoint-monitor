import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';

String virusTotalHeadline(String verdict) {
  switch (verdict) {
    case 'malicious':
      return 'Malicious';
    case 'suspicious':
      return 'Suspicious';
    case 'clean_or_unknown':
      return 'Clean';
    case 'unknown':
      return 'Unknown';
    default:
      return verdict.isEmpty ? 'Unknown' : verdict;
  }
}

String virusTotalExplanation(String verdict) {
  switch (verdict) {
    case 'malicious':
      return 'At least one engine flagged this file as malicious.';
    case 'suspicious':
      return 'No malicious verdicts, but some engines reported suspicious.';
    case 'clean_or_unknown':
      return 'No malicious or suspicious engine hits for this hash.';
    case 'unknown':
      return 'VirusTotal has no result for this file, or scan stats are unavailable.';
    default:
      return 'See engine counts below.';
  }
}

Future<void> openProcessVirusTotalSheet(BuildContext context, ProcessInfo p) async {
  final bloc = context.read<ProcessBloc>();
  bloc.requestVirusTotalCheck(p.pid);
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (c) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: BlocBuilder<ProcessBloc, ProcessState>(
            bloc: bloc,
            builder: (c, st) {
              final loading =
                  st.vtLoadingPid == p.pid && st.vtByPid[p.pid] == null;
              final data = st.vtByPid[p.pid];
              if (loading) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 20),
                    Center(child: CircularProgressIndicator()),
                    SizedBox(height: 16),
                    Text('Checking VirusTotal…'),
                    SizedBox(height: 12),
                  ],
                );
              }
              if (data == null) {
                return const Text('Waiting for response…');
              }
              final ok = data['ok'] == true;
              if (!ok) {
                return Text(
                  'Check failed: ${data['error'] ?? 'unknown'}',
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                );
              }
              final verdictRaw = data['verdict']?.toString() ?? 'unknown';
              final headline = virusTotalHeadline(verdictRaw);
              final expl = virusTotalExplanation(verdictRaw);
              final mal =
                  data['malicious'] is num ? (data['malicious'] as num).toInt() : 0;
              final sus =
                  data['suspicious'] is num ? (data['suspicious'] as num).toInt() : 0;
              final harm =
                  data['harmless'] is num ? (data['harmless'] as num).toInt() : 0;
              final und =
                  data['undetected'] is num ? (data['undetected'] as num).toInt() : 0;
              final totalEngines = mal + sus + harm + und;
              final sha = data['sha256']?.toString() ?? '';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'VirusTotal',
                    style: EmDesign.labelCaps(c, Theme.of(c).colorScheme),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    style: Theme.of(c).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    style: Theme.of(c).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expl,
                    style: Theme.of(c).textTheme.bodySmall?.copyWith(
                          color: Theme.of(c).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Engines: $mal malicious · $sus suspicious · $harm harmless · $und undetected'
                    '${totalEngines > 0 ? ' ($totalEngines reporting)' : ''}',
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                  if (sha.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final u = Uri.parse(
                          'https://www.virustotal.com/gui/file/$sha',
                        );
                        final launched = await launchUrl(
                          u,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched && c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open VirusTotal link'),
                            ),
                          );
                        }
                      },
                      child: const Text('Open in VirusTotal'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
