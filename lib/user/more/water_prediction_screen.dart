import 'package:flutter/material.dart';
import 'water_prediction_service.dart';

class WaterPredictionScreen extends StatefulWidget {
  const WaterPredictionScreen({super.key});

  @override
  State<WaterPredictionScreen> createState() => _WaterPredictionScreenState();
}

class _WaterPredictionScreenState extends State<WaterPredictionScreen> {
  final WaterPredictionService _service = WaterPredictionService();

  int _selectedDays = 7;
  final List<int> _dayOptions = const [7, 14, 30];

  late Future<List<Map<String, dynamic>>> _usageFuture;
  late Future<List<Map<String, dynamic>>> _levelFuture;

  final TextEditingController _pumpLevelController = TextEditingController(
    text: '50',
  );
  String? _pumpResult;
  bool _pumpLoading = false;

  Map<String, dynamic>? _refillInfo;
  bool _refillLoading = true;

  Map<String, dynamic>? _finishInfo;
  bool _finishLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  void _loadPredictions() {
    setState(() {
      _usageFuture = _service.getUsagePrediction(daysAhead: _selectedDays);
      _levelFuture = _service.getLevelPrediction(daysAhead: _selectedDays);
    });
    _loadRefillInfo();
    _loadFinishInfo();
  }

  Future<void> _loadRefillInfo() async {
    setState(() => _refillLoading = true);
    try {
      final result = await _service.getNextRefillPrediction();
      setState(() => _refillInfo = result);
    } catch (e) {
      setState(
        () => _refillInfo = {'status': 'error', 'message': e.toString()},
      );
    } finally {
      setState(() => _refillLoading = false);
    }
  }

  Future<void> _loadFinishInfo() async {
    setState(() => _finishLoading = true);
    try {
      final result = await _service.getWaterFinishPrediction();
      setState(() => _finishInfo = result);
    } catch (e) {
      setState(
        () => _finishInfo = {'status': 'error', 'message': e.toString()},
      );
    } finally {
      setState(() => _finishLoading = false);
    }
  }

  void _onDaysChanged(int days) {
    if (days == _selectedDays) return;
    setState(() => _selectedDays = days);
    _loadPredictions();
  }

  Future<void> _checkPumpStatus() async {
    final input = double.tryParse(_pumpLevelController.text);
    if (input == null) return;

    setState(() => _pumpLoading = true);
    try {
      final status = await _service.getPumpPrediction(input);
      setState(() => _pumpResult = status);
    } catch (e) {
      setState(() => _pumpResult = 'Error');
    } finally {
      setState(() => _pumpLoading = false);
    }
  }

  @override
  void dispose() {
    _pumpLevelController.dispose();
    super.dispose();
  }

  bool _isTablet(double width) => width >= 700 && width < 1100;
  bool _isDesktop(double width) => width >= 1100;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = _isDesktop(width);
    final isTablet = _isTablet(width);
    final maxContentWidth = isDesktop
        ? 900.0
        : (isTablet ? 700.0 : double.infinity);
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text(
          'Water Tank Insights',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPredictions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadPredictions(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              children: [
                _buildDayRangeSelector(),
                const SizedBox(height: 20),
                if (isDesktop)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _usageSection()),
                        const SizedBox(width: 16),
                        Expanded(child: _levelSection()),
                      ],
                    ),
                  )
                else ...[
                  _usageSection(),
                  const SizedBox(height: 24),
                  _levelSection(),
                ],
                const SizedBox(height: 24),
                _sectionTitle('When Will Water Come Next?', Icons.schedule),
                const SizedBox(height: 8),
                _buildRefillCard(),
                const SizedBox(height: 16),
                _sectionTitle(
                  'When Will Water Finish?',
                  Icons.hourglass_bottom,
                ),
                const SizedBox(height: 8),
                _buildFinishCard(),
                const SizedBox(height: 24),
                _sectionTitle(
                  'Pump Status Predictor',
                  Icons.power_settings_new,
                ),
                const SizedBox(height: 8),
                _buildPumpCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _usageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('$_selectedDays-Day Usage Forecast', Icons.water_drop),
        const SizedBox(height: 8),
        _buildUsageCard(),
      ],
    );
  }

  Widget _levelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('$_selectedDays-Day Water Level Forecast', Icons.opacity),
        const SizedBox(height: 8),
        _buildLevelCard(),
      ],
    );
  }

  Widget _buildDayRangeSelector() {
    return _cardContainer(
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1E88E5)),
          const SizedBox(width: 10),
          const Text(
            'Forecast range:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: _dayOptions.map((days) {
                final selected = days == _selectedDays;
                final label = days == 7
                    ? 'Week'
                    : (days == 30 ? 'Month' : '$days Days');
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => _onDaysChanged(days),
                  selectedColor: const Color(0xFF1E88E5),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFFE3EEFB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E88E5), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageCard() {
    return _cardContainer(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingBox();
          }
          if (snapshot.hasError) {
            return _errorBox("Couldn't load usage prediction");
          }

          final predictions = snapshot.data!;
          final maxVal = predictions
              .map((e) => (e['predicted_value'] as num).toDouble())
              .reduce((a, b) => a > b ? a : b);

          final needsScroll = predictions.length > 10;
          final listContent = Column(
            children: predictions.map((item) {
              final value = (item['predicted_value'] as num).toDouble();
              final ratio = maxVal == 0 ? 0.0 : value / maxVal;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatDate(item['date']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 18,
                          backgroundColor: const Color(0xFFE3EEFB),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${value.toStringAsFixed(0)} L',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );

          if (needsScroll) {
            return SizedBox(
              height: 320,
              child: SingleChildScrollView(child: listContent),
            );
          }
          return listContent;
        },
      ),
    );
  }

  Widget _buildLevelCard() {
    return _cardContainer(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _levelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingBox();
          }
          if (snapshot.hasError) {
            return _errorBox("Couldn't load level prediction");
          }

          final predictions = snapshot.data!;
          final barWidth = predictions.length > 10 ? 36.0 : null;

          final bars = predictions.map((item) {
            final value = (item['predicted_value'] as num).toDouble().clamp(
              0,
              100,
            );
            final color = value < 30
                ? Colors.red
                : (value < 60 ? Colors.orange : const Color(0xFF1E88E5));

            final barContent = Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: value.toDouble(),
                  width: barWidth != null ? barWidth - 8 : null,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(item['date'], short: true),
                  style: const TextStyle(fontSize: 9, color: Colors.black54),
                ),
              ],
            );

            return barWidth != null
                ? SizedBox(width: barWidth, child: barContent)
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: barContent,
                    ),
                  );
          }).toList();

          return SizedBox(
            height: 140,
            child: barWidth != null
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: bars,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bars,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildRefillCard() {
    return _cardContainer(
      child: _refillLoading
          ? _loadingBox()
          : _buildTimingContent(
              info: _refillInfo,
              alreadyStatus: 'already_low',
              alreadyMessage: (info) =>
                  'Water level is already low (${info['current_level']}%). Pump should be ON now.',
              alreadyIcon: Icons.warning_amber_rounded,
              alreadyColor: Colors.orange,
              okLabel: (level) =>
                  'Current level: $level% — estimated to reach refill point in',
              okIcon: Icons.water_drop_outlined,
            ),
    );
  }

  Widget _buildFinishCard() {
    return _cardContainer(
      child: _finishLoading
          ? _loadingBox()
          : _buildTimingContent(
              info: _finishInfo,
              alreadyStatus: 'already_empty',
              alreadyMessage: (info) =>
                  'Water level is already at 0%. Tank is empty.',
              alreadyIcon: Icons.error_outline,
              alreadyColor: Colors.red,
              okLabel: (level) =>
                  'Current level: $level% — estimated to run out in',
              okIcon: Icons.hourglass_bottom,
            ),
    );
  }

  Widget _buildTimingContent({
    required Map<String, dynamic>? info,
    required String alreadyStatus,
    required String Function(Map<String, dynamic>) alreadyMessage,
    required IconData alreadyIcon,
    required Color alreadyColor,
    required String Function(dynamic) okLabel,
    required IconData okIcon,
  }) {
    if (info == null || info['status'] == 'error') {
      return _errorBox("Couldn't load prediction");
    }

    final status = info['status'];

    if (status == alreadyStatus) {
      return Row(
        children: [
          Icon(alreadyIcon, color: alreadyColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alreadyMessage(info),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    if (status == 'insufficient_data') {
      return Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blueGrey, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              info['message'] ?? 'Not enough data to estimate timing yet.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      );
    }

    final hours = (info['estimated_hours_remaining'] as num).toDouble();
    final estDateTime = DateTime.tryParse(info['estimated_datetime'] ?? '');
    final currentLevel = info['current_level'];

    String timeText;
    if (hours < 1) {
      timeText = 'less than an hour';
    } else if (hours < 24) {
      timeText = '~${hours.toStringAsFixed(1)} hours';
    } else {
      timeText = '~${(hours / 24).toStringAsFixed(1)} days';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(okIcon, color: const Color(0xFF1E88E5), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${okLabel(currentLevel)} $timeText',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (estDateTime != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3EEFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'Expected around: ${_formatDateTime(estDateTime)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[dt.weekday - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$dayName ${dt.day}/${dt.month}, $hour:$minute $period';
  }

  Widget _buildPumpCard() {
    return _cardContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a water level to check if the pump would turn ON or OFF',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pumpTextField(),
                        const SizedBox(height: 10),
                        _pumpCheckButton(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _pumpTextField()),
                        const SizedBox(width: 12),
                        _pumpCheckButton(),
                      ],
                    ),
              if (_pumpResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _pumpResult == 'ON'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pumpResult == 'ON' ? Icons.power : Icons.power_off,
                        color: _pumpResult == 'ON'
                            ? Colors.green
                            : Colors.grey.shade700,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pump: $_pumpResult',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _pumpResult == 'ON'
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pumpTextField() {
    return TextField(
      controller: _pumpLevelController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Water Level (%)',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _pumpCheckButton() {
    return ElevatedButton(
      onPressed: _pumpLoading ? null : _checkPumpStatus,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _pumpLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Check'),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _loadingBox() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorBox(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate, {bool short = false}) {
    try {
      final date = DateTime.parse(isoDate);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = days[date.weekday - 1];
      return short ? dayName : '$dayName ${date.day}/${date.month}';
    } catch (_) {
      return isoDate;
    }
  }
}
