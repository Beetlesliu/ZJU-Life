import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/canteen.dart';
import '../../models/favorite.dart';
import '../../services/canteen_service.dart';
import '../../widgets/header.dart';
import '../../widgets/cupertino_grouped.dart';
import '../../widgets/indicators.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/data_list_screen_mixin.dart';
import '../../providers/favorites_provider.dart';
import '../../design/colors.dart';
import '../../design/design_constants.dart';

class CanteenScreen extends StatefulWidget {
  final String? highlightCanteenId;
  final String? highlightWindowId;

  const CanteenScreen({
    super.key,
    this.highlightCanteenId,
    this.highlightWindowId,
  });

  @override
  State<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends State<CanteenScreen>
    with DataListScreenMixin<CanteenData, CanteenScreen> {
  final CanteenService _canteenService = CanteenService();
  String _selectedCampus = 'all';
  DateTime _lastUpdated = DateTime.now();
  DateTime _currentTime = DateTime.now();
  Timer? _minuteRefreshTimer;

  final List<Map<String, String>> _campusOptions = [
    {'id': 'all', 'name': '全部'},
    {'id': 'zijingang', 'name': '紫金港'},
    {'id': 'yuquan', 'name': '玉泉'},
    {'id': 'xixi', 'name': '西溪'},
    {'id': 'huajiachi', 'name': '华家池'},
  ];

  @override
  void initState() {
    super.initState();
    _scheduleMinuteRefresh();
    initDataListScreen();
  }

  @override
  void dispose() {
    _minuteRefreshTimer?.cancel();
    disposeDataListScreen();
    super.dispose();
  }

  // ============ Mixin Implementation ============

  @override
  String? getInitialHighlightId() => widget.highlightCanteenId;

  @override
  Future<void> loadData() async {
    if (!mounted) return;
    setState(_updateCurrentTime);
    await super.loadData();
    if (mounted) setState(_updateCurrentTime);
  }

  @override
  Future<List<CanteenData>> fetchData() async {
    final response = await _canteenService.fetchCanteenData();
    _lastUpdated = response.fetchedAt;
    _updateCurrentTime();
    return response.canteens;
  }

  @override
  String getItemId(CanteenData item) => item.id;

  @override
  Widget buildItem(BuildContext context, CanteenData item, bool isHighlighted) {
    return _CanteenCard(
      canteen: item,
      isHighlighted: isHighlighted,
    );
  }

  @override
  List<CanteenData> filterItems(List<CanteenData> items) {
    // Filter by campus
    List<CanteenData> filtered;
    if (_selectedCampus == 'all') {
      filtered = List.from(items);
    } else {
      filtered = _canteenService.filterByCampus(items, _selectedCampus);
    }

    // Sort favorites to top
    final favoritesProvider = context.read<FavoritesProvider>();
    final favoriteIds = favoritesProvider.favorites
        .where((f) => f.type == FavoriteType.canteen)
        .map((f) => f.id)
        .toSet();

    filtered.sort((a, b) {
      final aFav = favoriteIds.contains('canteen_${a.id}');
      final bFav = favoriteIds.contains('canteen_${b.id}');
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return filtered;
  }

  // ============ Custom UI ============

  void _scheduleMinuteRefresh() {
    _minuteRefreshTimer?.cancel();

    final now = DateTime.now();
    final nextMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final delay =
        nextMinute.difference(now) + const Duration(milliseconds: 100);

    _minuteRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      setState(_updateCurrentTime);
      _scheduleMinuteRefresh();
    });
  }

  void _updateCurrentTime() {
    _currentTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: buildScreenBody(
          header: const PageHeader(
            title: '食堂',
            subtitle: '实时拥挤度',
          ),
          additionalContent: Column(
            children: [
              _buildCampusFilter(),
              _buildUpdateInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: _campusOptions.map((campus) {
            final isSelected = campus['id'] == _selectedCampus;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                pressedOpacity: 0.72,
                onPressed: () =>
                    setState(() => _selectedCampus = campus['id']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.primaryColor.withValues(alpha: 0.13)
                        : context.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? context.primaryColor
                          : context.dividerColor.withValues(alpha: 0.7),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          LucideIcons.check,
                          size: 14,
                          color: context.primaryColor,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        campus['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? context.primaryColor
                              : context.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUpdateInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.clock,
                size: 14,
                color: context.secondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                '更新于 ${_formatTime(_lastUpdated)}',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          TextButton.icon(
            onPressed: loadData,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('刷新'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = _currentTime.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _CanteenCard extends StatelessWidget {
  final CanteenData canteen;
  final bool isHighlighted;

  const _CanteenCard({
    required this.canteen,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusDynamic(canteen.crowdLevel);
    return AnimatedContainer(
      duration: DesignConstants.highlightAnimationDuration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: context.primaryColor,
                width: DesignConstants.highlightBorderWidth,
              )
            : null,
      ),
      child: CupertinoGroupSection(
        children: [
          CupertinoGroupRow(
            icon: LucideIcons.utensils,
            iconColor: statusColor.dark,
            title: canteen.name,
            subtitle: canteen.currentCount == null
                ? '容量 ${canteen.capacity} 人'
                : '${canteen.currentCount} / ${canteen.capacity} 人',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FavoriteButton(
                  itemId: 'canteen_${canteen.id}',
                  type: FavoriteType.canteen,
                  title: canteen.name,
                  subtitle: '容量 ${canteen.capacity} 人',
                  data: {
                    'campus': canteen.campus,
                    'capacity': canteen.capacity,
                  },
                  size: 22,
                ),
                const SizedBox(width: 8),
                CrowdLevel(
                  level: canteen.crowdLevel,
                  compact: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: ProgressIndicatorBar(
              progress: canteen.crowdLevel,
              showPercentage: false,
              height: 6,
            ),
          ),
        ],
      ),
    );
  }

  DynamicColor _getStatusDynamic(double level) {
    if (level < 0.3) return AppColors.okGreen;
    if (level < 0.6) return AppColors.sand;
    if (level < 0.85) return AppColors.autumn;
    return AppColors.summer;
  }
}
