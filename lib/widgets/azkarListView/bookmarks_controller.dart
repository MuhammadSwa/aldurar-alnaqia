import 'package:get/get.dart';
import 'package:yosria/services/shared_prefs.dart';

class BookmarksController extends GetxController {
  var bookmarks = SharedPreferencesService.getBookmarks();

  List<String> getBookmarks() {
    return SharedPreferencesService.getBookmarks();
  }

  void addBookmark(String bookmark) {
    SharedPreferencesService.addBookmark(bookmark);
    bookmarks = getBookmarks();
    update();
  }

  void removeBookmark(String bookmark) {
    SharedPreferencesService.removeBookmark(bookmark);
    bookmarks = getBookmarks();
    update();
  }

  // check if bookmarks exists and toggle bookmark
  bool toggleBookmark(String bookmark) {
    final wasBookmark = getBookmarks().contains(bookmark);
    if (wasBookmark) {
      removeBookmark(bookmark);
    } else {
      addBookmark(bookmark);
    }
    return wasBookmark;
  }

  // void setBookmarks(List<String> bookmarks) {
  //   SharedPreferencesService.setBookmarks(bookmarks);
  // }
  //
  // void removeAllBookmarks() {
  //   SharedPreferencesService.removeAllBookmarks();
  // }
}
