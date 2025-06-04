import 'dart:ui';

import 'package:aldurar_alnaqia/widgets/azkarListView/bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO: الهمزة والألف نفس الشي
// NOTE: do you ne to virturalize the list for performance?
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
    // _controller.clear(); // Optional: clear text each time modal opens
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
  // bool _showSuggestions = false; 

  @override
  void initState() {
    super.initState();
    // Initialize with all suggestions if available, ensuring it's a mutable copy.
    _filteredSuggestions = List.from(widget.suggestions ?? const []);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure widget is still in the tree
        widget.focusNode.requestFocus();
      }
    });

    widget.controller.addListener(_onTextChanged);
    // Manually trigger _onTextChanged if controller already has text (e.g., if not cleared)
    // This ensures initial state is correct if modal reopens with existing text.
    _onTextChanged();
  }

  void _onTextChanged() {
    if (!mounted) return; // Avoid calling setState if widget is disposed

    // If no base suggestions are provided, or they are empty, _filteredSuggestions should remain empty.
    if (widget.suggestions == null || widget.suggestions!.isEmpty) {
      if (_filteredSuggestions.isNotEmpty) {
        setState(() {
          _filteredSuggestions = [];
        });
      }
      return;
    }

    final query = widget.controller.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // If query is empty, show all original suggestions
        _filteredSuggestions = List.from(widget.suggestions!);
      } else {
        // Otherwise, filter
        _filteredSuggestions = widget.suggestions!
            .where((suggestion) => suggestion.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _performSearch(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      widget.onSearch
          ?.call(trimmedQuery); // Call the onSearch callback if provided

      if (mounted) {
        Navigator.of(context).pop();
      }

      // Example navigation, adjust as per your app's routing
      // If SearchModal is part of a specific feature, it might navigate within that feature.
      // For generic search, the onSearch callback is often preferred.
      // context.go('/awradScreen/zikr/$trimmedQuery');
    }
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: suggestion.length)); // Move cursor to end
    _performSearch(suggestion);
    // _onTextChanged will be called by the listener, updating _filteredSuggestions.
    // If you want to immediately close or hide suggestions after selection, handle here.
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget suggestionsArea;

    // Case 1: Suggestions are available from the widget's input
    if (widget.suggestions != null && widget.suggestions!.isNotEmpty) {
      if (_filteredSuggestions.isNotEmpty) {
        // Subcase 1.1: There are suggestions to display (either all or filtered)
        suggestionsArea = ListView.builder(
          padding: EdgeInsets.zero, // Adjust padding as needed
          itemCount: _filteredSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _filteredSuggestions[index];
            return ListTile(
              leading: BookmarkButton(bookmarkId: suggestion),
              title: Text(
                suggestion,
                style: const TextStyle(
                    color: Colors.white), // Consider themable color
              ),
              onTap: () => _selectSuggestion(suggestion),
            );
          },
        );
      } else {
        // Subcase 1.2: Suggestions were provided, but the current filter query yields no results.
        suggestionsArea = Center(
          child: Text(
            widget.controller.text.isEmpty
                ? 'Type to see suggestions' // Should not happen if suggestions are provided initially and query is empty
                : 'لا توجد نتائج بحث ل"${widget.controller.text}"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300], // Consider themable color
            ),
          ),
        );
      }
    } else {
      // Case 2: No suggestions were provided to the SearchModal initially.
      suggestionsArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400], // Consider themable color
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your search query',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300], // Consider themable color
              ),
            ),
          ],
        ),
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[400], // Consider themable color
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Search header
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
                        hintStyle: TextStyle(
                            color: Colors.grey[300]), // Consider themable color
                        prefixIcon:
                            const Icon(Icons.search), // Consider themable color
                        suffixIcon: widget.controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                    Icons.clear), // Consider themable color
                                onPressed: () {
                                  widget.controller.clear();
                                  // _onTextChanged will be called by the listener.
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          // borderSide: BorderSide.none, // If you prefer no border lines
                        ),
                        filled: false, // If true, define fillColor
                        // fillColor: Colors.grey[800], // Example if filled: true
                      ),
                      onSubmitted: _performSearch,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                          color: Colors
                              .white), // Input text color, consider theming
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('إلغاء'), // Consider themable style
                  ),
                ],
              ),
            ),

            // Suggestions or content area
            Expanded(
              child: suggestionsArea,
            ),
          ],
        ),
      ),
    );
  }
}
