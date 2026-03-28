import 'package:flutter/material.dart';

import '../../../data/repositories/video_repository.dart';

/// Reusable widget that displays full video analysis results.
class AnalysisResultsCard extends StatelessWidget {
  final VideoAnalysis analysis;

  const AnalysisResultsCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final isApproved =
        !analysis.isGloballyBlacklisted &&
        analysis.violenceScore <= 4.0 &&
        analysis.audioSafetyScore >= 4.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verdict
            Row(
              children: [
                Icon(
                  isApproved ? Icons.check_circle : Icons.cancel,
                  color: isApproved ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isApproved ? 'APPROVED' : 'REJECTED',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isApproved ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                _ConfidenceBadge(confidence: analysis.confidence),
              ],
            ),
            const SizedBox(height: 12),

            // Age range
            Row(
              children: [
                const Icon(Icons.cake, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Ages ${analysis.ageMinAppropriate}-${analysis.ageMaxAppropriate}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Score gauges
            const Text(
              'Safety Scores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _ScoreRow(
              'Educational',
              analysis.educationalScore,
              Colors.blue,
              invert: true,
            ),
            _ScoreRow(
              'Overstimulation',
              analysis.overstimulationScore,
              Colors.orange,
            ),
            _ScoreRow('Brainrot', analysis.brainrotScore, Colors.purple),
            _ScoreRow('Scariness', analysis.scarinessScore, Colors.indigo),
            _ScoreRow(
              'Language',
              analysis.languageSafetyScore,
              Colors.teal,
              invert: true,
            ),
            _ScoreRow('Violence', analysis.violenceScore, Colors.red),
            _ScoreRow(
              'Audio Safety',
              analysis.audioSafetyScore,
              Colors.cyan,
              invert: true,
            ),
            const SizedBox(height: 12),

            // Content labels
            if (analysis.contentLabels.isNotEmpty) ...[
              const Text(
                'Content Labels',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: analysis.contentLabels.map((label) {
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Detected issues
            if (analysis.detectedIssues.isNotEmpty) ...[
              const Text(
                'Detected Issues',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 6),
              ...analysis.detectedIssues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(issue, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Reasoning
            if (analysis.analysisReasoning.isNotEmpty) ...[
              const Text(
                'Analysis Reasoning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                analysis.analysisReasoning,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final Color color;
  final bool invert;

  const _ScoreRow(this.label, this.score, this.color, {this.invert = false});

  @override
  Widget build(BuildContext context) {
    // For inverted scores (educational, language safety, audio safety),
    // higher is better. For others, lower is better.
    final normalized = score / 10.0;
    final dangerLevel = invert ? 1.0 - normalized : normalized;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: normalized,
                backgroundColor: Colors.grey[200],
                color: dangerLevel > 0.6
                    ? Colors.red
                    : dangerLevel > 0.3
                    ? Colors.orange
                    : Colors.green,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$pct% confidence',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }
}
