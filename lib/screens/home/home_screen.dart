import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../design/colors.dart';
import '../../design/design_constants.dart';
import '../../widgets/cards.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/campus_provider.dart';
import '../../services/canteen_service.dart';
import '../../services/bus_service.dart';
import '../../models/canteen.dart';
import '../../models/bus.dart';
import '../../models/favorite.dart';
import '../../widgets/cupertino_grouped.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 实时数据
  final CanteenService _canteenService = CanteenService();
  final BusService _busService = BusService();

  List<CanteenData>? _canteenData;
  List<BusRoute>? _busRoutes;
  bool _isLoadingLiveData = false;
  DateTime _currentTime = DateTime.now();
  Timer? _minuteRefreshTimer;

  @override
  void initState() {
    super.initState();
    _scheduleMinuteRefresh();
    _loadLiveData();
  }

  @override
  void dispose() {
    _minuteRefreshTimer?.cancel();
    super.dispose();
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

  Future<void> _loadLiveData() async {
    if (_isLoadingLiveData) {
      setState(_updateCurrentTime);
      return;
    }

    setState(() {
      _updateCurrentTime();
      _isLoadingLiveData = true;
    });

    try {
      // 并行加载食堂和班车数据
      final results = await Future.wait([
        _canteenService
            .fetchCanteenData()
            .then((r) => r.canteens)
            .catchError((_) => <CanteenData>[]),
        _busService
            .fetchBusRoutes(BusType.campusShuttle)
            .catchError((_) => <BusRoute>[]),
      ]);

      if (mounted) {
        setState(() {
          _updateCurrentTime();
          _canteenData = results[0] as List<CanteenData>;
          _busRoutes = results[1] as List<BusRoute>;
        });
      }
    } catch (_) {
      // 静默失败
    } finally {
      if (mounted) {
        setState(() {
          _updateCurrentTime();
          _isLoadingLiveData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final campus = context.watch<CampusProvider>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 顶部安全区域
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
          ),

          // 顶部欢迎区域
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildHeader(auth, campus),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: DesignConstants.spacingXL)),

          // 快捷入口卡片组
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildQuickEntries(),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: DesignConstants.spacingL)),

          // 收藏区域 - 始终显示
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildFavoritesSection(favorites),
            ),
          ),

          // 登录提示
          if (!auth.isAuthenticated)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildLoginPrompt(),
              ),
            ),

          // 底部间距
          SliverToBoxAdapter(
            child:
                SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, CampusProvider campus) {
    final greeting = _getGreeting(_currentTime.hour);
    final dateStr = DateFormat('M月d日 EEEE', 'zh_CN').format(_currentTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary.resolve(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.okGreen.dark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: DesignConstants.spacingS),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.resolve(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.dividerColor.withValues(alpha: 0.42),
                    width: 0.5,
                  ),
                  boxShadow: context.cardShadow,
                ),
                child: Icon(
                  auth.isAuthenticated
                      ? LucideIcons.user
                      : LucideIcons.slidersHorizontal,
                  size: 20,
                  color: context.secondaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignConstants.spacingL),
        _buildCampusSelector(campus),
      ],
    );
  }

  Widget _buildCampusSelector(CampusProvider campus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showCampusPicker(campus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.winter.dark.withValues(alpha: 0.18)
              : AppColors.winter.light,
          borderRadius: DesignConstants.cardRadius(),
          border: Border.all(
            color: AppColors.winter.dark.withValues(alpha: 0.22),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 16,
              color: AppColors.winter.dark,
            ),
            const SizedBox(width: DesignConstants.spacingS),
            Text(
              campus.selectedCampus.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.winter.dark,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: AppColors.winter.dark,
            ),
          ],
        ),
      ),
    );
  }

  void _showCampusPicker(CampusProvider campus) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择校区'),
        actions: Campus.values.map((c) {
          final isSelected = c == campus.selectedCampus;
          return CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.selectionClick();
              campus.selectCampus(c);
              Navigator.of(sheetContext).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 18,
                    color: context.primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(c.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 6) return '夜深了 🌙';
    if (hour < 9) return '早上好 ☀️';
    if (hour < 12) return '上午好 🌤';
    if (hour < 14) return '中午好 🍜';
    if (hour < 18) return '下午好 ☕';
    if (hour < 22) return '晚上好 🌆';
    return '夜深了 🌙';
  }

  Widget _buildQuickEntries() {
    return CupertinoGroupSection(
      header: '快捷入口',
      children: [
        CupertinoGroupRow(
          icon: LucideIcons.utensils,
          iconColor: AppColors.peach.dark,
          title: '食堂',
          subtitle: '查看实时拥挤度',
          showChevron: true,
          onTap: () => context.go('/canteen'),
        ),
        CupertinoGroupRow(
          icon: LucideIcons.bookOpen,
          iconColor: AppColors.okGreen.dark,
          title: '自习',
          subtitle: '查看图书馆座位',
          showChevron: true,
          onTap: () => context.go('/study'),
        ),
        CupertinoGroupRow(
          icon: LucideIcons.bus,
          iconColor: AppColors.violet.dark,
          title: '班车',
          subtitle: '校区班车与校内环线',
          showChevron: true,
          onTap: () => context.go('/bus'),
        ),
      ],
    );
  }

  Widget _buildFavoritesSection(FavoritesProvider favorites) {
    final isEmpty = favorites.favorites.isEmpty;

    return CupertinoGroupSection(
      header: '我的收藏',
      headerTrailing: isEmpty
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => context.go('/profile'),
              child: Text(
                '管理',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.primaryColor,
                ),
              ),
            ),
      children: isEmpty
          ? [
              CupertinoGroupRow(
                icon: LucideIcons.heartOff,
                iconColor: context.secondaryColor,
                title: '暂无收藏',
                subtitle: '在食堂、班车页面点击喜欢按钮添加收藏',
              ),
            ]
          : favorites.favorites
              .take(5)
              .map(
                (item) => _LiveFavoriteCard(
                  item: item,
                  canteenData: _canteenData,
                  busRoutes: _busRoutes,
                  currentTime: _currentTime,
                  onTap: () => _navigateToFavorite(item),
                ),
              )
              .toList(),
    );
  }

  void _navigateToFavorite(FavoriteItem item) {
    switch (item.type) {
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        context.go('/canteen');
        break;
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        context.go('/bus');
        break;
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        context.go('/study');
        break;
      case FavoriteType.custom:
        break;
    }
  }

  Widget _buildLoginPrompt() {
    return RoundCard(
      onTap: () => context.go('/login'),
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.zjuBlue.dark,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.zjuBlue.dark,
              AppColors.zjuBlue.dark.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '解锁完整体验',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '登录统一身份认证，使用收藏、座位预约等功能',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: DesignConstants.smallRadius(),
                    ),
                    child: Text(
                      '立即登录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.zjuBlue.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.logIn,
              size: 44,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带实时数据的收藏卡片
class _LiveFavoriteCard extends StatelessWidget {
  final FavoriteItem item;
  final List<CanteenData>? canteenData;
  final List<BusRoute>? busRoutes;
  final DateTime currentTime;
  final VoidCallback? onTap;

  const _LiveFavoriteCard({
    required this.item,
    this.canteenData,
    this.busRoutes,
    required this.currentTime,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final liveInfo = _getLiveInfo();

    return CupertinoGroupRow(
      icon: item.icon,
      iconColor: _getTypeColor(item.type),
      title: item.title,
      subtitle: item.subtitle ?? '',
      showChevron: liveInfo == null,
      trailing: liveInfo == null
          ? null
          : liveInfo.isProgressBar
              ? _buildProgressWidget(context, liveInfo)
              : _buildLiveInfoWidget(context, liveInfo),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
    );
  }

  Widget _buildLiveInfoWidget(BuildContext context, _LiveInfo info) {
    return CupertinoMetricPill(
      text: info.mainText,
      subtext: info.subText,
      color: info.color,
    );
  }

  Widget _buildProgressWidget(BuildContext context, _LiveInfo info) {
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info.mainText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: info.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: info.progress ?? 0,
              backgroundColor: brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(info.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.subText ?? '',
            style: TextStyle(
              fontSize: 9,
              color: brightness == Brightness.dark
                  ? Colors.white60
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  _LiveInfo? _getLiveInfo() {
    switch (item.type) {
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return _getCanteenLiveInfo();
      case FavoriteType.busRoute:
        return _getBusLiveInfo();
      default:
        return null;
    }
  }

  _LiveInfo? _getCanteenLiveInfo() {
    if (canteenData == null) return null;

    // 通过名称匹配食堂
    final canteen = canteenData!
        .where(
            (c) => c.name.contains(item.title) || item.title.contains(c.name))
        .firstOrNull;

    if (canteen == null || canteen.currentCount == null) return null;

    final crowdLevel = canteen.crowdLevel;
    final Color color;
    if (crowdLevel < 0.3) {
      color = AppColors.okGreen.dark;
    } else if (crowdLevel < 0.6) {
      color = AppColors.cyan.dark;
    } else if (crowdLevel < 0.85) {
      color = AppColors.peach.dark;
    } else {
      color = const Color(0xFFDC2626);
    }

    return _LiveInfo(
      mainText: canteen.crowdStatus,
      subText: '${canteen.currentCount}/${canteen.capacity}人',
      color: color,
      progress: crowdLevel,
      isProgressBar: true,
    );
  }

  _LiveInfo? _getBusLiveInfo() {
    if (busRoutes == null) return null;

    // 从 data 获取路线ID
    final routeId = item.data?['routeId'] as String?;
    if (routeId == null) return null;

    final route = busRoutes!.where((r) => r.id == routeId).firstOrNull;
    if (route == null) return null;

    // 获取下一班车
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    BusSchedule? nextBus;
    for (final schedule in route.schedules) {
      if (schedule.departureMinutes > currentMinutes &&
          schedule.isOperatingToday) {
        nextBus = schedule;
        break;
      }
    }

    if (nextBus == null) {
      return _LiveInfo(
        mainText: '今日无',
        subText: '明日首班',
        color: const Color(0xFF64748B),
      );
    }

    final waitMinutes = nextBus.departureMinutes - currentMinutes;
    final Color color;
    if (waitMinutes <= 10) {
      color = AppColors.okGreen.dark;
    } else if (waitMinutes <= 30) {
      color = AppColors.violet.dark;
    } else {
      color = const Color(0xFF64748B);
    }

    return _LiveInfo(
      mainText: nextBus.departureTime,
      subText: waitMinutes <= 60 ? '$waitMinutes分钟后' : '下一班',
      color: color,
    );
  }

  Color _getTypeColor(FavoriteType type) {
    switch (type) {
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        return AppColors.violet.dark;
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return AppColors.peach.dark;
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        return AppColors.okGreen.dark;
      case FavoriteType.custom:
        return AppColors.cyan.dark;
    }
  }
}

class _LiveInfo {
  final String mainText;
  final String? subText;
  final Color color;
  final double? progress;
  final bool isProgressBar;

  _LiveInfo({
    required this.mainText,
    this.subText,
    required this.color,
    this.progress,
    this.isProgressBar = false,
  });
}
