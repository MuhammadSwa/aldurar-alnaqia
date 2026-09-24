// city_picker.dart
//
// Searchable offline city picker used in [PrayerSettingsDialog].
//
// [CityPickerField] shows the current selection (or a placeholder) and
// opens [CitySearchSheet]: a bottom sheet with a search field and a
// virtualized [ListView.builder] of matches (at most 60 rows are ever
// built, no matter how many cities match).

import 'dart:async';

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Read-only field that displays the chosen city and opens the search sheet.
class CityPickerField extends StatelessWidget {
  const CityPickerField({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final City? selected;
  final ValueChanged<City> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      icon: const Icon(Icons.search),
      label: Align(
        alignment: Alignment.centerRight,
        child: Text(
          selected == null ? 'ابحث عن مدينتك…' : selected!.displayName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null
                ? theme.hintColor
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onPressed: () async {
        final picked = await showModalBottomSheet<City>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => CitySearchSheet(initial: selected),
        );
        if (picked != null) onSelected(picked);
      },
    );
  }
}

/// Bottom sheet: search field on top, virtualized results below.
class CitySearchSheet extends ConsumerStatefulWidget {
  const CitySearchSheet({super.key, this.initial});

  final City? initial;

  @override
  ConsumerState<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends ConsumerState<CitySearchSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directoryAsync = ref.watch(cityDirectoryProvider);

    // Full-height sheet: no bottom padding, no viewInsets (keyboard
    // overlays the lower results). useSafeArea on the modal keeps the
    // sheet off the system nav bar.
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'اسم المدينة أو الدولة',
                hintText: 'مثال: القاهرة أو مصر أو Cairo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: directoryAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text('تعذر تحميل قائمة المدن: $error'),
                ),
                data: (directory) => _ResultsList(
                  directory: directory,
                  query: _query,
                  initial: widget.initial,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.directory,
    required this.query,
    required this.initial,
  });

  final CityDirectory directory;
  final String query;
  final City? initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (CityDirectory.normalize(query).isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(
            'اكتب اسم المدينة أو الدولة بالعربية أو الإنجليزية',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    final result = directory.searchWithCount(query);
    final results = result.results;
    if (results.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج مطابقة، جرّب اسمًا آخر'),
      );
    }

    final total = result.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > results.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'عرض أول ${results.length} من $total نتيجة — دقّق البحث أكثر',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
        Expanded(
          // Virtualized: only visible rows are built, regardless of how
          // many cities match.
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final city = results[index];
              final isSelected = initial != null &&
                  initial!.latitude == city.latitude &&
                  initial!.longitude == city.longitude &&
                  initial!.nameEn == city.nameEn;
              final subtitle = [
                if (city.nameAr != null) city.nameEn,
                directory.countryLabel(city.countryCode),
              ].join('، ');
              return ListTile(
                title: Text(city.displayName),
                subtitle: Text(subtitle),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(city),
              );
            },
          ),
        ),
      ],
    );
  }
}
