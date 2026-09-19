import 'dart:ui';

import 'package:aldurar_alnaqia/common/helpers/arabic.dart'
    show normalizeArabic;
import 'package:aldurar_alnaqia/models/azkar_models.dart' show zikrIdForTitle;
import 'package:aldurar_alnaqia/widgets/azkar_list_view/bookmark_button.dart';
import 'package:material_ui/material_ui.dart';

/// Titles that should lead results for common names which imply related azkar.
///
/// Keys use normalized Arabic (for example, `ة` becomes `ه`). The rest of the
/// literal matches retain the order supplied by the registry.
const _preferredSuggestionsByQuery = <String, List<String>>{
  'حزب': [
    'حزب البحر',
    'حزب البر (الحزب الكبير)',
    'حزب النصر',
    'حزب الإمام النووي',
    'حزب الفتح الصديقي',
  ],
  'برده': ['قصيدة بانت سعاد', 'بردة الإمام البوصيري'],
  'البرده': ['قصيدة بانت سعاد', 'بردة الإمام البوصيري'],
};

List<String> _preferredSuggestionsForQuery(String normalizedQuery) {
  for (final entry in _preferredSuggestionsByQuery.entries) {
    if (entry.key.startsWith(normalizedQuery)) {
      return entry.value;
    }
  }
  return const <String>[];
}

final RegExp _searchWordSeparator =
    RegExp(r'''[\s\(\)\[\]\{\}،؛؟:!"'،.\-_/\\]+''');

List<String> _searchWords(String normalizedText) => normalizedText
    .split(_searchWordSeparator)
    .where((word) => word.isNotEmpty)
    .toList();

int? _wordMatchScore(
  List<String> queryWords,
  List<String> suggestionWords, {
  required bool allowSubstring,
}) {
  var positions = 0;
  for (final queryWord in queryWords) {
    final position = suggestionWords.indexWhere(
      (suggestionWord) => allowSubstring
          ? suggestionWord.contains(queryWord)
          : suggestionWord.startsWith(queryWord),
    );
    if (position == -1) return null;
    positions += position;
  }
  return positions;
}

bool _isOneEditAway(String first, String second) {
  if ((first.length - second.length).abs() > 1) return false;

  var firstIndex = 0;
  var secondIndex = 0;
  var edits = 0;
  while (firstIndex < first.length && secondIndex < second.length) {
    if (first[firstIndex] == second[secondIndex]) {
      firstIndex++;
      secondIndex++;
      continue;
    }

    if (++edits > 1) return false;
    if (first.length > second.length) {
      firstIndex++;
    } else if (first.length < second.length) {
      secondIndex++;
    } else {
      firstIndex++;
      secondIndex++;
    }
  }
  return edits + (first.length - firstIndex) + (second.length - secondIndex) <=
      1;
}

bool _hasFuzzyWordMatch(
  List<String> queryWords,
  List<String> suggestionWords,
) {
  return queryWords.every(
    (queryWord) =>
        queryWord.length >= 4 &&
        suggestionWords.any(
          (suggestionWord) =>
              suggestionWord.length >= 4 &&
              _isOneEditAway(queryWord, suggestionWord),
        ),
  );
}

/// Returns a relevance score for a normalized query and suggestion.
///
/// Lower scores are better. The tiers favour exact and prefix matches, then
/// word matches (which tolerate extra words and changed spacing), followed by
/// a one-character typo in a meaningful word.
int? _searchScore(String query, String suggestion) {
  if (suggestion == query) return 0;
  if (suggestion.startsWith(query)) return 10;

  final compactQuery = query.replaceAll(' ', '');
  final compactSuggestion = suggestion.replaceAll(' ', '');
  if (compactSuggestion.startsWith(compactQuery)) return 15;
  if (suggestion.contains(query)) return 20;

  final queryWords = _searchWords(query);
  final suggestionWords = _searchWords(suggestion);
  final prefixWordPositions = _wordMatchScore(
    queryWords,
    suggestionWords,
    allowSubstring: false,
  );
  if (prefixWordPositions != null) return 30 + prefixWordPositions;

  final substringWordPositions = _wordMatchScore(
    queryWords,
    suggestionWords,
    allowSubstring: true,
  );
  if (substringWordPositions != null) return 50 + substringWordPositions;

  return _hasFuzzyWordMatch(queryWords, suggestionWords) ? 70 : null;
}

/// Filters suggestions by relevance and puts related azkar first for a few
/// common queries.
List<String> filterAndRankSuggestions(String query, List<String> suggestions) {
  final normalizedQuery = normalizeArabic(query);
  if (normalizedQuery.isEmpty) return List<String>.from(suggestions);

  final preferredSuggestions = _preferredSuggestionsForQuery(normalizedQuery);
  final preferredIndexes = <String, int>{
    for (var index = 0; index < preferredSuggestions.length; index++)
      preferredSuggestions[index]: index,
  };

  final matches = <({String suggestion, int score, int originalIndex})>[];
  for (var index = 0; index < suggestions.length; index++) {
    final suggestion = suggestions[index];
    final preferredIndex = preferredIndexes[suggestion];
    final score = _searchScore(normalizedQuery, normalizeArabic(suggestion));
    if (preferredIndex != null || score != null) {
      matches.add(
        (
          suggestion: suggestion,
          // Curated suggestions always lead; all other results are ranked by
          // the same general relevance rules.
          score: preferredIndex ?? 100 + score!,
          originalIndex: index,
        ),
      );
    }
  }

  matches.sort((a, b) {
    final scoreComparison = a.score.compareTo(b.score);
    return scoreComparison != 0
        ? scoreComparison
        : a.originalIndex.compareTo(b.originalIndex);
  });
  return [for (final match in matches) match.suggestion];
}

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

    setState(() {
      if (query.isEmpty) {
        _filteredSuggestions = List.from(widget.suggestions!);
      } else {
        _filteredSuggestions = filterAndRankSuggestions(
          query,
          widget.suggestions!,
        );
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
    // Full-height sheet that ignores the keyboard: no viewInsets padding,
    // no shrinking. The keyboard overlays the lower part of the list.
    // Subtract only the top system padding so we never slide under the
    // status bar; the bottom SafeArea below keeps us off the nav bar when
    // the keyboard is closed (its padding goes to 0 when the keyboard
    // opens, so content continues under the keyboard).
    final availableHeight = mediaQuery.size.height - mediaQuery.viewPadding.top;
    final sheetHeight = availableHeight;

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

    // Bottom SafeArea only (uses viewPadding, not the keyboard), so the
    // sheet rests above the nav bar but slides under the keyboard.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        final bookmarkId = zikrIdForTitle(suggestion) ?? suggestion;
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
