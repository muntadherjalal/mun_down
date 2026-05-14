import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../injection_container.dart' as di;
import '../../../browser/presentation/pages/browser_page.dart';
import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import '../../../downloader/presentation/pages/downloader_page.dart';
import '../../../downloads_history/presentation/pages/pages.dart';
import '../../../files/presentation/pages/files_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

/// Root scaffold with a 4-tab bottom navigation bar.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final _pageController = PageController();
  late final DownloaderBloc _downloaderBloc;

  @override
  void initState() {
    super.initState();
    _downloaderBloc = di.sl<DownloaderBloc>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _downloaderBloc.close();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider<DownloaderBloc>.value(
        value: _downloaderBloc,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            BrowserPage(onTabSwitch: _onTabTapped),
            const DownloaderPage(),
            const FilesPage(),
            const DownloadsHistoryPage(),
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(icon: Icons.language_rounded, label: 'Browser', isSelected: _currentIndex == 0, onTap: () => _onTabTapped(0)),
              // Downloads tab with badge
              BlocBuilder<DownloaderBloc, DownloaderState>(
                bloc: _downloaderBloc,
                builder: (context, state) {
                  final isActive = state is DownloaderFetchingState ||
                      state is DownloaderProgressState ||
                      state is DownloaderPausedState;
                  return _TabItem(
                    icon: Icons.download_rounded,
                    label: 'Downloads',
                    isSelected: _currentIndex == 1,
                    onTap: () => _onTabTapped(1),
                    showBadge: isActive,
                  );
                },
              ),
              _TabItem(icon: Icons.video_library_rounded, label: 'Library', isSelected: _currentIndex == 2, onTap: () => _onTabTapped(2)),
              _TabItem(icon: Icons.history_rounded, label: 'History', isSelected: _currentIndex == 3, onTap: () => _onTabTapped(3)),
              _TabItem(icon: Icons.settings_rounded, label: 'Settings', isSelected: _currentIndex == 4, onTap: () => _onTabTapped(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim, size: 24),
                  if (showBadge)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.kSurface, width: 2),
                          boxShadow: [BoxShadow(color: AppTheme.neonCyan.withAlpha(100), blurRadius: 6)],
                        ),
                        child: const Center(
                          child: Text('1', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: isSelected ? AppTheme.neonCyan : Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
