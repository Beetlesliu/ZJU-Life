import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/bus.dart';
import '../../models/favorite.dart';
import '../../services/bus_service.dart';
import '../../widgets/header.dart';
import '../../widgets/cards.dart';
import '../../widgets/cupertino_grouped.dart';
import '../../widgets/indicators.dart';
import '../../widgets/favorite_button.dart';
import '../../design/colors.dart';
import '../../design/design_constants.dart';

class BusScreen extends StatefulWidget {
  final String? highlightRouteId;
  final String? highlightStopId;

  const BusScreen({
    super.key,
    this.highlightRouteId,
    this.highlightStopId,
  });

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final BusService _busService = BusService();

  // 校区班车状态
  bool _isLoadingShuttle = true;
  String? _shuttleError;
  List<BusRoute> _shuttleRoutes = [];

  // 校内环线状态 (小白车)
  bool _isLoadingInternal = true;
  String? _internalError;
  List<BusRoute> _internalRoutes = [];

  // 高亮状态
  String? _highlightedRouteId;
  DateTime _currentTime = DateTime.now();
  Timer? _minuteRefreshTimer;

  @override
  void initState() {
    super.initState();
    _highlightedRouteId = widget.highlightRouteId;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _scheduleMinuteRefresh();
    _loadData();
  }

  @override
  void dispose() {
    _minuteRefreshTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(_updateCurrentTime);
  }

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

  Future<void> _loadData() async {
    await Future.wait([
      _loadShuttleData(),
      _loadInternalData(),
    ]);

    // 数据加载完成后，滚动到目标路线
    if (_highlightedRouteId != null) {
      _scrollToHighlightedRoute();
    }
  }

  void _scrollToHighlightedRoute() {
    if (_highlightedRouteId == null) return;

    // 在下一帧执行，确保UI已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 查找目标路线的索引（先在校区班车中找，再在校内环线中找）
      final allRoutes = [..._shuttleRoutes, ..._internalRoutes];
      final index = allRoutes.indexWhere((r) => r.id == _highlightedRouteId);

      if (index != -1 && _scrollController.hasClients) {
        // 如果在校内环线中，切换到对应的Tab
        if (index >= _shuttleRoutes.length) {
          _tabController.animateTo(1);
        }

        // 计算滚动位置
        const headerHeight = 100.0;
        const tabHeight = 48.0;
        const cardHeight = 200.0;
        final actualIndex = index >= _shuttleRoutes.length
            ? index - _shuttleRoutes.length
            : index;
        final targetOffset =
            headerHeight + tabHeight + (actualIndex * cardHeight) - 20;

        // 平滑滚动到目标位置
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              targetOffset.clamp(
                  0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        });

        // 3秒后清除高亮
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _highlightedRouteId = null;
            });
          }
        });
      }
    });
  }

  Future<void> _loadShuttleData() async {
    if (!mounted) return;
    setState(() {
      _updateCurrentTime();
      _isLoadingShuttle = true;
      _shuttleError = null;
    });

    try {
      final routes = await _busService.fetchBusRoutes(BusType.campusShuttle);
      if (!mounted) return;
      setState(() {
        _updateCurrentTime();
        _shuttleRoutes = routes;
        _isLoadingShuttle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateCurrentTime();
        _isLoadingShuttle = false;
        _shuttleError = e.toString();
      });
    }
  }

  Future<void> _loadInternalData() async {
    if (!mounted) return;
    setState(() {
      _updateCurrentTime();
      _isLoadingInternal = true;
      _internalError = null;
    });

    try {
      final routes = await _busService.fetchBusRoutes(BusType.campusInternal);
      if (!mounted) return;
      setState(() {
        _updateCurrentTime();
        _internalRoutes = routes;
        _isLoadingInternal = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateCurrentTime();
        _isLoadingInternal = false;
        _internalError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const PageHeader(
              title: '班车',
              subtitle: '校区通勤',
            ),

            // iOS-style segmented control
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: DesignConstants.pagePadding.horizontal / 2,
                  vertical: DesignConstants.spacingM),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tabController.index,
                backgroundColor: context.secondaryBackgroundColor,
                thumbColor: context.cardColor,
                padding: const EdgeInsets.all(3),
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('校区班车'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('校内环线'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  HapticFeedback.selectionClick();
                  _tabController.animateTo(value);
                },
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShuttleTab(),
                  _buildInternalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 校区班车 Tab ============
  Widget _buildShuttleTab() {
    if (_isLoadingShuttle) {
      return const Center(
        child: LoadingIndicator(message: '加载中...'),
      );
    }

    if (_shuttleError != null) {
      return Center(
        child: ErrorState(
          message: _shuttleError!,
          onRetry: _loadShuttleData,
        ),
      );
    }

    if (_shuttleRoutes.isEmpty) {
      return Center(
        child: EmptyState(
          icon: LucideIcons.bus,
          title: '暂无班车数据',
          subtitle: '请稍后重试',
          action: ElevatedButton(
            onPressed: _loadShuttleData,
            child: const Text('重试'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShuttleData,
      color: context.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: DesignConstants.pagePadding,
        itemCount: _shuttleRoutes.length,
        itemBuilder: (context, index) {
          final route = _shuttleRoutes[index];
          final isHighlighted = _highlightedRouteId == route.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShuttleRouteCard(
              route: route,
              isHighlighted: isHighlighted,
              currentTime: _currentTime,
            ),
          );
        },
      ),
    );
  }

  // ============ 校内环线 Tab (小白车) ============
  Widget _buildInternalTab() {
    if (_isLoadingInternal) {
      return const Center(
        child: LoadingIndicator(message: '加载中...'),
      );
    }

    if (_internalError != null) {
      return Center(
        child: ErrorState(
          message: _internalError!,
          onRetry: _loadInternalData,
        ),
      );
    }

    if (_internalRoutes.isEmpty) {
      return Center(
        child: EmptyState(
          icon: LucideIcons.bus,
          title: '暂无小白车数据',
          subtitle: '请稍后重试',
          action: ElevatedButton(
            onPressed: _loadInternalData,
            child: const Text('重试'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInternalData,
      color: context.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: DesignConstants.pagePadding,
        itemCount: _internalRoutes.length,
        itemBuilder: (context, index) {
          final route = _internalRoutes[index];
          final isHighlighted = _highlightedRouteId == route.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InternalRouteCard(
              route: route,
              isHighlighted: isHighlighted,
              currentTime: _currentTime,
            ),
          );
        },
      ),
    );
  }
}

/// 校区班车线路卡片
class _ShuttleRouteCard extends StatelessWidget {
  final BusRoute route;
  final bool isHighlighted;
  final DateTime currentTime;

  const _ShuttleRouteCard({
    required this.route,
    this.isHighlighted = false,
    required this.currentTime,
  });

  // 校区坐标
  static const Map<String, Map<String, double>> _campusLocations = {
    '紫金港': {'lat': 30.308597, 'lng': 120.087424},
    '玉泉': {'lat': 30.262765, 'lng': 120.125523},
    '西溪': {'lat': 30.271823, 'lng': 120.100758},
    '华家池': {'lat': 30.270583, 'lng': 120.197028},
    '海宁': {'lat': 30.463889, 'lng': 120.690833},
    '舟山': {'lat': 29.946390, 'lng': 122.101389},
  };

  String? _extractDestination() {
    // 从线路名称中提取目的地校区
    for (final campus in _campusLocations.keys) {
      if (route.name.contains(campus)) {
        return campus;
      }
    }
    return null;
  }

  Future<void> _openNavigation(BuildContext context) async {
    final destination = _extractDestination();
    if (destination == null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('无法导航'),
          content: const Text('无法识别目的地校区'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
      return;
    }

    final coords = _campusLocations[destination]!;
    final lat = coords['lat']!;
    final lng = coords['lng']!;

    // 显示导航选项
    _showNavigationOptions(context, destination, lat, lng);
  }

  void _showNavigationOptions(
      BuildContext context, String destination, double lat, double lng) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text('导航至 $destination'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _launchAmap(lat, lng, destination);
            },
            child: const Text('高德地图'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _launchBaidu(lat, lng, destination);
            },
            child: const Text('百度地图'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _launchMaps(lat, lng, destination);
            },
            child: const Text('Apple/Google 地图'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _launchAmap(double lat, double lng, String name) async {
    // 高德地图
    final amapUrl = Uri.parse(
        'amapuri://route/plan/?dlat=$lat&dlon=$lng&dname=$name&dev=0&t=0');
    final webUrl = Uri.parse(
        'https://uri.amap.com/navigation?to=$lng,$lat,$name&mode=car&coordinate=gaode');

    if (await canLaunchUrl(amapUrl)) {
      await launchUrl(amapUrl);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchBaidu(double lat, double lng, String name) async {
    // 百度地图
    final baiduUrl = Uri.parse(
        'baidumap://map/direction?destination=latlng:$lat,$lng|name:$name&coord_type=gcj02&mode=driving');
    final webUrl = Uri.parse(
        'https://api.map.baidu.com/direction?destination=latlng:$lat,$lng|name:$name&coord_type=gcj02&mode=driving&output=html');

    if (await canLaunchUrl(baiduUrl)) {
      await launchUrl(baiduUrl);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMaps(double lat, double lng, String name) async {
    // Apple Maps / Google Maps
    final url = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final nextSchedule = _getNextSchedule();

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
            icon: LucideIcons.bus,
            iconColor: AppColors.cyan.dark,
            title: route.name,
            subtitle: route.notes,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RouteTag(text: route.routeNumber),
                const SizedBox(width: 8),
                FavoriteButton(
                  itemId: 'bus_${route.id}',
                  type: FavoriteType.busRoute,
                  title: route.name,
                  subtitle: route.routeNumber,
                  data: {
                    'routeNumber': route.routeNumber,
                    'scheduleCount': route.schedules.length,
                  },
                  size: 22,
                ),
              ],
            ),
          ),
          if (nextSchedule != null)
            CupertinoGroupRow(
              icon: LucideIcons.clock,
              iconColor: AppColors.okGreen.dark,
              title: '下一班',
              subtitle: '共 ${route.schedules.length} 班',
              trailing: CupertinoMetricPill(
                text: nextSchedule.departureTime,
                color: AppColors.okGreen.dark,
              ),
            ),
          CupertinoGroupRow(
            icon: LucideIcons.navigation,
            iconColor: AppColors.cyan.dark,
            title: '导航到校区',
            showChevron: true,
            onTap: () {
              HapticFeedback.lightImpact();
              _openNavigation(context);
            },
          ),
        ],
      ),
    );
  }

  BusSchedule? _getNextSchedule() {
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    for (final schedule in route.schedules) {
      if (schedule.departureMinutes > currentMinutes) {
        return schedule;
      }
    }
    return route.schedules.isNotEmpty ? route.schedules.first : null;
  }
}

class _RouteTag extends StatelessWidget {
  final String text;

  const _RouteTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = context.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: context.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: resolvedColor,
          height: 1,
        ),
      ),
    );
  }
}

/// 小白车线路卡片
class _InternalRouteCard extends StatefulWidget {
  final BusRoute route;
  final bool isHighlighted;
  final DateTime currentTime;

  const _InternalRouteCard({
    required this.route,
    this.isHighlighted = false,
    required this.currentTime,
  });

  @override
  State<_InternalRouteCard> createState() => _InternalRouteCardState();
}

class _InternalRouteCardState extends State<_InternalRouteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final nextSchedule = _getNextSchedule();
    final isClockwise = widget.route.id == 'internal_route1';

    return AnimatedContainer(
      duration: DesignConstants.highlightAnimationDuration,
      decoration: BoxDecoration(
        borderRadius: DesignConstants.cardRadius(),
        border: widget.isHighlighted
            ? Border.all(
                color: context.primaryColor,
                width: DesignConstants.highlightBorderWidth,
              )
            : null,
      ),
      child: CupertinoGroupSection(
        children: [
          // 主要信息区域
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBox(
                        icon: isClockwise
                            ? LucideIcons.rotateCw
                            : LucideIcons.rotateCcw,
                        color: isClockwise ? AppColors.okGreen : AppColors.cyan,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isClockwise
                                            ? AppColors.okGreen
                                            : AppColors.cyan)
                                        .resolve(context)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.route.routeNumber,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isClockwise
                                          ? AppColors.okGreen.dark
                                          : AppColors.cyan.dark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.route.name,
                                    style:
                                        context.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '共 ${widget.route.schedules.length} 班',
                              style: context.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        color: context.secondaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                  if (nextSchedule != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 16,
                            color: AppColors.okGreen.dark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '下一班：',
                            style: context.textTheme.bodySmall,
                          ),
                          Text(
                            nextSchedule.departureTime,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.okGreen.dark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getWaitTime(nextSchedule),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppColors.okGreen.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 展开区域 - 线路详情
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 站点信息
                  if (widget.route.notes != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 16,
                          color: context.secondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.route.notes!,
                            style: context.textTheme.bodySmall?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 发车时刻表
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: context.secondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '发车时间：',
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.route.schedules.map((schedule) {
                      final isPast = _isPastTime(schedule);
                      final isNext = schedule == nextSchedule;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isNext
                              ? AppColors.okGreen.dark.withValues(alpha: 0.15)
                              : isPast
                                  ? context.backgroundColor
                                      .withValues(alpha: 0.5)
                                  : context.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                          border: isNext
                              ? Border.all(
                                  color: AppColors.okGreen.dark, width: 1)
                              : null,
                        ),
                        child: Text(
                          schedule.departureTime,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isNext ? FontWeight.w600 : FontWeight.w500,
                            color: isNext
                                ? AppColors.okGreen.dark
                                : isPast
                                    ? context.secondaryColor
                                        .withValues(alpha: 0.5)
                                    : context.textColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  BusSchedule? _getNextSchedule() {
    final currentMinutes =
        widget.currentTime.hour * 60 + widget.currentTime.minute;

    for (final schedule in widget.route.schedules) {
      if (schedule.departureMinutes > currentMinutes) {
        return schedule;
      }
    }
    return null;
  }

  bool _isPastTime(BusSchedule schedule) {
    final currentMinutes =
        widget.currentTime.hour * 60 + widget.currentTime.minute;
    return schedule.departureMinutes <= currentMinutes;
  }

  String _getWaitTime(BusSchedule schedule) {
    final currentMinutes =
        widget.currentTime.hour * 60 + widget.currentTime.minute;
    final waitMinutes = schedule.departureMinutes - currentMinutes;

    if (waitMinutes <= 0) return '即将发车';
    if (waitMinutes < 60) return '约 $waitMinutes 分钟';
    final hours = waitMinutes ~/ 60;
    final mins = waitMinutes % 60;
    return '约 $hours 小时 $mins 分钟';
  }
}
