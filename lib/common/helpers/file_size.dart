/// Formats a byte count for display: whole KB below 1 MB,
// otherwise MB with one decimal (e.g. `850 KB`, `12.4 MB`).
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
