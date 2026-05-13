import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../injection_container.dart' as di;
import '../../../browser/presentation/pages/browser_page.dart';
import '../../../downloader/presentation/bloc/downloader_bloc.dart';
import '../../../downloader/presentation/pages/downloader_page.dart';
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

  // PageController keeps tab state alive via PageView.
  final _pageController = PageController();

  // Provide a dedicated BLoC to the Downloads tab.
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
          children: const [
            BrowserPage(),
            DownloaderPage(),
            FilesPage(),
            SettingsPage(),
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
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                icon: Icons.language_rounded,
                label: 'Browser',
                isSelected: _currentIndex == 0,
                onTap: () => _onTabTapped(0),
              ),
              _TabItem(
                icon: Icons.download_rounded,
                label: 'Downloads',
                isSelected: _currentIndex == 1,
                onTap: () => _onTabTapped(1),
              ),
              _TabItem(
                icon: Icons.video_library_rounded,
                label: 'Library',
                isSelected: _currentIndex == 2,
                onTap: () => _onTabTapped(2),
              ),
              _TabItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: _currentIndex == 3,
                onTap: () => _onTabTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single tab item in the bottom bar.
class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
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
              Icon(
                icon,
                color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              // Active indicator: 3px neon underline
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isSelected ? AppTheme.neonCyan : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
