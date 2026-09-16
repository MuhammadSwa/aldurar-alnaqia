import 'dart:ui';

import 'package:aldurar_alnaqia/common/helpers/arabic.dart'
    show normalizeArabic;
import 'package:aldurar_alnaqia/models/azkar_models.dart' show resolveZikr;
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmark_button.dart';
import 'package:flutter/material.dart';

// SearchWidget remains the same
class SearchWidget extends StatefulWidget {
  final Function(String)? onSearch;
  final String? hintText;
  final List<String>? suggestions;

  const SearchWidget({
    super.key,
    this.onSearch,
    this.hintText = 'Search...',
    this.suggestions,
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _showSearchModal() {
    // Clear previous text before showing modal if desired, or manage state differently
    _controller.clear(); // clear text each time modal opens
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchModal(
        controller: _controller,
        focusNode: _focusNode,
        onSearch: widget.onSearch,
        hintText: widget.hintText,
        suggestions: widget.suggestions,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      onPressed: _showSearchModal,
      tooltip: 'بحث',
    );
  }
}

class SearchModal extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String)? onSearch;
  final String? hintText;
  final List<String>? suggestions;

  const SearchModal({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSearch,
    this.hintText,
    this.suggestions,
  });

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _filteredSuggestions = List.from(widget.suggestions ?? const []);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.focusNode.requestFocus();
      }
    });

    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Normalizes Arabic text for better search matching.
  /// Shared with the city picker via [normalizeArabic].
  String _normalizeArabic(String text) => normalizeArabic(text);

  void _onTextChanged() {
    if (!mounted) return;

    if (widget.suggestions == null || widget.suggestions!.isEmpty) {
      if (_filteredSuggestions.isNotEmpty) {
        setState(() {
          _filteredSuggestions = [];
        });
      }
      return;
    }

    final query = widget.controller.text;
    // Normalize query for better filtering
    final normalizedQuery = _normalizeArabic(query.toLowerCase());

    setState(() {
      if (query.isEmpty) {
        _filteredSuggestions = List.from(widget.suggestions!);
      } else {
        // Filter suggestions based on the normalized query
        _filteredSuggestions = widget.suggestions!
            .where((suggestion) => _normalizeArabic(suggestion.toLowerCase())
                .contains(normalizedQuery))
            .toList();
      }
    });
  }

  /// Checks if the query matches a valid route before performing the search.
  void _performSearch(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return; // Do nothing if the search query is empty
    }

    // Ensure we have suggestions to validate against
    if (widget.suggestions == null || widget.suggestions!.isEmpty) {
      return; // Cannot validate, so do nothing to prevent errors
    }

    final normalizedQuery = _normalizeArabic(trimmedQuery.toLowerCase());

    // Find a suggestion that is an exact match to the query (after normalization)
    final String matchingSuggestion = widget.suggestions!.firstWhere(
      (suggestion) =>
          _normalizeArabic(suggestion.toLowerCase()) == normalizedQuery,
      orElse: () => '', // Return an empty string if no match is found
    );

    // Only proceed if a valid, matching route was found
    if (matchingSuggestion.isNotEmpty) {
      // Use the canonical suggestion name for navigation
      widget.onSearch?.call(matchingSuggestion);

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    // If no match is found, do nothing. The user stays on the search modal.
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    widget.controller.selection =
        TextSelection.fromPosition(TextPosition(offset: suggestion.length));
    _performSearch(suggestion);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    // Available height below the status bar. The modal itself already avoids
    // the top intrusion via `useSafeArea: true`, so size the sheet from what
    // is left to guarantee it never slides under the status bar.
    // Shrink the sheet by the keyboard height so the keyboard sits below
    // the sheet instead of covering it; total height stays at 90%.
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewPadding.top;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final sheetHeight = (availableHeight * 0.9 - keyboardHeight)
        .clamp(0.0, availableHeight);

    final hasSuggestions =
        widget.suggestions != null && widget.suggestions!.isNotEmpty;
    final Widget suggestionsArea;
    if (hasSuggestions && _filteredSuggestions.isNotEmpty) {
      suggestionsArea = _SuggestionsList(
        suggestions: _filteredSuggestions,
        onTap: _selectSuggestion,
      );
    } else {
      suggestionsArea = _SearchEmptyState(
        hasQuery: hasSuggestions,
        queryText: widget.controller.text,
        onSurfaceVariant: onSurfaceVariant,
      );
    }

    // Outer SafeArea handles the bottom (home indicator); top/left/right are
    // already handled by `useSafeArea: true` on the modal, so don't apply
    // them twice. Bottom padding lifts the sheet above the keyboard so it
    // resizes instead of being covered.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _SearchTextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  hintText: widget.hintText,
                  onSubmitted: _performSearch,
                  onCancel: () {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  onSurface: onSurface,
                  onSurfaceVariant: onSurfaceVariant,
                ),
                Expanded(child: suggestionsArea),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;
  final Color onSurface;
  final Color onSurfaceVariant;

  const _SearchTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    required this.onCancel,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: onSurfaceVariant),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: controller.clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: false,
              ),
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: onSurface),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionsList({
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        // Suggestions are display titles; bookmarks store stable ids.
        final bookmarkId = resolveZikr(suggestion)?.id ?? suggestion;
        return ListTile(
          leading: BookmarkButton(bookmarkId: bookmarkId),
          title: Text(
            suggestion,
            style: TextStyle(color: onSurface),
          ),
          onTap: () => onTap(suggestion),
        );
      },
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  /// True when suggestions were provided (query mode); false when there is
  /// no search context (suggestions null/empty).
  final bool hasQuery;
  final String queryText;
  final Color onSurfaceVariant;

  const _SearchEmptyState({
    required this.hasQuery,
    required this.queryText,
    required this.onSurfaceVariant,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasQuery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your search query',
              style: TextStyle(
                fontSize: 16,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Text(
        queryText.isEmpty
            ? 'Type to see suggestions'
            : 'لا توجد نتائج بحث ل"$queryText"',
        style: TextStyle(
          fontSize: 16,
          color: onSurfaceVariant,
        ),
      ),
    );
  }
}
