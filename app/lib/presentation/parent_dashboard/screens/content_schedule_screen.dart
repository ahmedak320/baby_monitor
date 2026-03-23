import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../domain/services/content_schedule_service.dart';

class ContentScheduleScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  const ContentScheduleScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<ContentScheduleScreen> createState() =>
      _ContentScheduleScreenState();
}

class _ContentScheduleScreenState extends ConsumerState<ContentScheduleScreen> {
  final _service = ContentScheduleService();
  List<ContentScheduleBlock> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final blocks = await _service.getSchedule(widget.childId);
    if (mounted) {
      setState(() {
        _blocks = blocks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName} - Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBlock,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Templates bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Text('Templates: ',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      for (final name in ContentScheduleService.templateNames)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(_formatTemplateName(name)),
                            onPressed: () async {
                              await _service.applyTemplate(
                                  widget.childId, name);
                              _loadSchedule();
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Schedule blocks
                Expanded(
                  child: _blocks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No schedule set'),
                              SizedBox(height: 8),
                              Text(
                                'Add time blocks or use a template',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _blocks.length,
                          itemBuilder: (context, index) {
                            final block = _blocks[index];
                            return _ScheduleBlockCard(
                              block: block,
                              onDelete: () async {
                                await _service.deleteBlock(block.id);
                                _loadSchedule();
                              },
                              onToggle: () async {
                                await _service.updateBlock(block.id, {
                                  'is_enabled': !block.isEnabled,
                                });
                                _loadSchedule();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _addBlock() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddBlockDialog(),
    );
    if (result == null) return;

    await _service.addBlock(ContentScheduleBlock(
      id: '',
      childId: widget.childId,
      startHour: result['start_hour'] as int,
      endHour: result['end_hour'] as int,
      allowedContentTypes: result['types'] as List<String>,
    ));
    _loadSchedule();
  }

  String _formatTemplateName(String name) {
    return name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _ScheduleBlockCard extends StatelessWidget {
  final ContentScheduleBlock block;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ScheduleBlockCard({
    required this.block,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: block.isEnabled ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatHour(block.startHour)} - ${_formatHour(block.endHour)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: block.isEnabled ? null : Colors.grey,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: block.isEnabled,
                  onChanged: (_) => onToggle(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: block.allowedContentTypes.map((type) {
                return Chip(
                  label: Text(type, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

class _AddBlockDialog extends StatefulWidget {
  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  int _startHour = 8;
  int _endHour = 12;
  final Set<String> _selectedTypes = {'educational', 'nature'};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Time Block'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Range'),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _startHour,
                    isExpanded: true,
                    items: List.generate(24, (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_formatHour(i)),
                    )),
                    onChanged: (v) => setState(() => _startHour = v!),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                Expanded(
                  child: DropdownButton<int>(
                    value: _endHour,
                    isExpanded: true,
                    items: List.generate(24, (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_formatHour(i)),
                    )),
                    onChanged: (v) => setState(() => _endHour = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Allowed Content Types'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: AppConstants.contentTypes.map((type) {
                final selected = _selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedTypes.isNotEmpty
              ? () => Navigator.pop(context, {
                    'start_hour': _startHour,
                    'end_hour': _endHour,
                    'types': _selectedTypes.toList(),
                  })
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}
