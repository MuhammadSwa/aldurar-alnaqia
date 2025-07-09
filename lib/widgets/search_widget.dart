import 'dart:ui';

import 'package:aldurar_alnaqia/widgets/azkarListView/bookmark_button.dart';
import 'package:flutter/material.dart';

// TODO: الهمزة والألف نفس الشي
// NOTE: do you ne to virturalize the list for performance? ListView.builder?
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
  /// Treats different forms of Alif as one, and Teh Marbuta as Haa.
  String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

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
    Widget suggestionsArea;

    if (widget.suggestions != null && widget.suggestions!.isNotEmpty) {
      if (_filteredSuggestions.isNotEmpty) {
        suggestionsArea = ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _filteredSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _filteredSuggestions[index];
            return ListTile(
              leading: BookmarkButton(bookmarkId: suggestion),
              title: Text(
                suggestion,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => _selectSuggestion(suggestion),
            );
          },
        );
      } else {
        suggestionsArea = Center(
          child: Text(
            widget.controller.text.isEmpty
                ? 'Type to see suggestions'
                : 'لا توجد نتائج بحث ل"${widget.controller.text}"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300],
            ),
          ),
        );
      }
    } else {
      suggestionsArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your search query',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      );
    }

    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
        child: SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: TextStyle(color: Colors.grey[300]),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: widget.controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      widget.controller.clear();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: false,
                          ),
                          onSubmitted: _performSearch,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: suggestionsArea,
                ),
              ],
            ),
          ),
        ));
  }
}
