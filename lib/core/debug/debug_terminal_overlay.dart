import 'package:exel_ott/core/debug/technical_log_entry.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugTerminalOverlay extends StatefulWidget {
  const DebugTerminalOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DebugTerminalOverlay> createState() => _DebugTerminalOverlayState();
}

class _DebugTerminalOverlayState extends State<DebugTerminalOverlay> {
  final _scrollController = ScrollController();
  Offset _panelOffset = const Offset(12, 80);
  double _panelWidth = 340;
  double _panelHeight = 420;

  @override
  void initState() {
    super.initState();
    TechnicalLogStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    TechnicalLogStore.instance.removeListener(_onStoreChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = TechnicalLogStore.instance;
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        widget.child,
        if (store.showFab)
          Positioned(
            right: 16,
            bottom: 24,
            child: Material(
              color: const Color(0xFF1E1E1E),
              elevation: 6,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: store.expand,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.terminal, color: Color(0xFF4ADE80), size: 20),
                ),
              ),
            ),
          ),
        if (store.isExpanded)
          Positioned(
            left: _panelOffset.dx.clamp(0, size.width - 120),
            top: _panelOffset.dy.clamp(0, size.height - 120),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0D1117),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _panelWidth.clamp(280, size.width - 24),
                  height: _panelHeight.clamp(240, size.height - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TerminalHeader(
                        entryCount: store.entries.length,
                        onDrag: (delta) {
                          setState(() {
                            _panelOffset += delta;
                          });
                        },
                        onMinimize: store.minimize,
                        onClear: store.clear,
                        onClose: store.disable,
                      ),
                      const Divider(height: 1, color: Color(0xFF30363D)),
                      Expanded(
                        child: store.entries.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sin logs aún.\nEjecuta login u otra acción.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8B949E),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(8),
                                itemCount: store.entries.length,
                                itemBuilder: (context, index) {
                                  return _LogEntryTile(entry: store.entries[index]);
                                },
                              ),
                      ),
                      _ResizeHandle(
                        onResize: (delta) {
                          setState(() {
                            _panelWidth = (_panelWidth + delta.dx).clamp(280, size.width - 24);
                            _panelHeight = (_panelHeight + delta.dy).clamp(240, size.height - 48);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({
    required this.entryCount,
    required this.onDrag,
    required this.onMinimize,
    required this.onClear,
    required this.onClose,
  });

  final int entryCount;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onMinimize;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => onDrag(details.delta),
      child: Container(
        color: const Color(0xFF161B22),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Color(0xFFFF5F57)),
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 10, color: Color(0xFFFEBC2E)),
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 10, color: Color(0xFF28C840)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Terminal técnica ($entryCount)',
                style: const TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF8B949E)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onMinimize,
              icon: const Icon(Icons.minimize, color: Color(0xFF8B949E)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onResize});

  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => onResize(details.delta),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.open_in_full, size: 14, color: Color(0xFF484F58)),
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatefulWidget {
  const _LogEntryTile({required this.entry});

  final TechnicalLogEntry entry;

  @override
  State<_LogEntryTile> createState() => _LogEntryTileState();
}

class _LogEntryTileState extends State<_LogEntryTile> {
  bool _expanded = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final levelColor = switch (e.level) {
      TechnicalLogLevel.info => const Color(0xFF58A6FF),
      TechnicalLogLevel.request => const Color(0xFFD2A8FF),
      TechnicalLogLevel.response => const Color(0xFF4ADE80),
      TechnicalLogLevel.error => const Color(0xFFF85149),
    };

    final time =
        '${e.timestamp.hour.toString().padLeft(2, '0')}:'
        '${e.timestamp.minute.toString().padLeft(2, '0')}:'
        '${e.timestamp.second.toString().padLeft(2, '0')}';

    final hasDetails = (e.body?.isNotEmpty ?? false) ||
        (e.fields?.isNotEmpty ?? false) ||
        (e.error?.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        e.category,
                        style: TextStyle(
                          color: levelColor,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.title,
                        style: TextStyle(
                          color: e.level == TechnicalLogLevel.error
                              ? const Color(0xFFF85149)
                              : const Color(0xFFC9D1D9),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (e.durationMs != null)
                      Text(
                        '${e.durationMs}ms',
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    if (hasDetails) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: const Color(0xFF8B949E),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_expanded && hasDetails) ...[
              const Divider(height: 1, color: Color(0xFF30363D)),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (e.statusCode != null)
                      _DetailLine(label: 'status', value: e.statusCode.toString()),
                    if (e.error != null) _DetailLine(label: 'error', value: e.error!),
                    if (e.fields != null)
                      for (final entry in e.fields!.entries)
                        _DetailLine(label: entry.key, value: entry.value),
                    if (e.body != null) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'body',
                              style: TextStyle(
                                color: Color(0xFF8B949E),
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF58A6FF),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: e.body!));
                              if (!mounted) return;
                              setState(() => _copied = true);
                              await Future<void>.delayed(const Duration(seconds: 1));
                              if (mounted) setState(() => _copied = false);
                            },
                            icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                            label: Text(
                              _copied ? 'Copiado' : 'Copiar',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          _truncate(e.body!, 8000),
                          style: const TextStyle(
                            color: Color(0xFF7EE787),
                            fontFamily: 'monospace',
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}\n… (truncado, usa Copiar para el texto completo)';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF8B949E)),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFFC9D1D9)),
            ),
          ],
        ),
      ),
    );
  }
}
