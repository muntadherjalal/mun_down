import 'package:flutter/material.dart';
import '../../../../core/themes/app_theme.dart';
import '../pages/files_page.dart'; // To get LibraryFilter and ViewMode

class FilesControlBar extends StatelessWidget {
  final LibraryFilter currentFilter;
  final ValueChanged<LibraryFilter> onFilterChanged;
  final ViewMode viewMode;
  final ValueChanged<ViewMode> onViewModeChanged;

  const FilesControlBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filters
          _buildFilterChip(context, 'All', LibraryFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Video', LibraryFilter.video),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Audio', LibraryFilter.audio),
          const Spacer(),
          // View Mode Toggles
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider(context)),
            ),
            child: Row(
              children: [
                _buildViewModeButton(context, Icons.view_list_rounded, ViewMode.list),
                _buildViewModeButton(context, Icons.grid_view_rounded, ViewMode.grid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, LibraryFilter filter) {
    final isSelected = currentFilter == filter;
    return InkWell(
      onTap: () => onFilterChanged(filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.neonCyan.withAlpha(25)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.neonCyan : AppTheme.onSurface(context).withAlpha(40),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.neonCyan : AppTheme.dimText(context),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeButton(BuildContext context, IconData icon, ViewMode mode) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () => onViewModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.onSurface(context).withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? AppTheme.onSurface(context) : AppTheme.dimText(context),
        ),
      ),
    );
  }
}
