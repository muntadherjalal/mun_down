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
          _buildFilterChip('All', LibraryFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Video', LibraryFilter.video),
          const SizedBox(width: 8),
          _buildFilterChip('Audio', LibraryFilter.audio),
          const Spacer(),
          // View Mode Toggles
          Container(
            decoration: BoxDecoration(
              color: AppTheme.kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                _buildViewModeButton(Icons.view_list_rounded, ViewMode.list),
                _buildViewModeButton(Icons.grid_view_rounded, ViewMode.grid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LibraryFilter filter) {
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
            color: isSelected ? AppTheme.neonCyan : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.neonCyan : AppTheme.kTextDim,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeButton(IconData icon, ViewMode mode) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () => onViewModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : AppTheme.kTextDim,
        ),
      ),
    );
  }
}
