// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'download_controller.dart'; // Adjust import path
//
// class DownloadProgressWidget extends StatelessWidget {
//   const DownloadProgressWidget({
//     super.key,
//     required this.id,
//     required this.onCancel,
//   });
//
//   final String id;
//   final VoidCallback? onCancel;
//
//   @override
//   Widget build(BuildContext context) {
//     return GetBuilder<DownloaderController>(
//       builder: (controller) {
//         final progress = controller.getDownloadProgress(id) ?? 0.0;
//
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             IconButton(
//               onPressed: onCancel,
//               icon: const Icon(Icons.close),
//               tooltip: 'إلغاء التحميل',
//             ),
//             Stack(
//               alignment: Alignment.center,
//               children: [
//                 CircularProgressIndicator(
//                   value: progress,
//                   color: Colors.blue,
//                 ),
//                 Text(
//                   '${(progress * 100).round()}%',
//                   style: Theme.of(context).textTheme.bodySmall,
//                 ),
//               ],
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// class DeleteDownloadedButton extends StatelessWidget {
//   const DeleteDownloadedButton({
//     super.key,
//     required this.id,
//     required this.title,
//     required this.type,
//     required this.onDelete,
//   });
//
//   final String id;
//   final String title;
//   final DownloadType type;
//   final VoidCallback? onDelete;
//
//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       onPressed: () => _showDeleteConfirmation(context),
//       icon: const Icon(Icons.delete_outline),
//       tooltip: 'حذف الملف',
//     );
//   }
//
//   void _showDeleteConfirmation(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('تأكيد الحذف'),
//         content: Text('هل أنت متأكد من حذف "$title"؟'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('إلغاء'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               onDelete?.call();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text(
//               'حذف',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class DownloadButton extends StatelessWidget {
//   const DownloadButton({
//     super.key,
//     required this.downloadItem,
//     required this.onDownload,
//   });
//
//   final DownloadItem downloadItem;
//   final VoidCallback? onDownload;
//
//   @override
//   Widget build(BuildContext context) {
//     return GetBuilder<DownloaderController>(
//       builder: (controller) {
//         // Check if currently downloading
//         if (controller.isDownloading(downloadItem.id)) {
//           return DownloadProgressWidget(
//             id: downloadItem.id,
//             onCancel: () => controller.cancelDownload(downloadItem.id),
//           );
//         }
//
//         // Use FutureBuilder for file status check
//         return FutureBuilder<bool>(
//           future:
//               controller.isFileDownloaded(downloadItem.id, downloadItem.type),
//           builder: (context, snapshot) {
//             // Show skeleton while loading
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               );
//             }
//
//             final isDownloaded = snapshot.data ?? false;
//
//             if (isDownloaded) {
//               return DeleteDownloadedButton(
//                 id: downloadItem.id,
//                 title: downloadItem.title,
//                 type: downloadItem.type,
//                 onDelete: () =>
//                     controller.deleteFile(downloadItem.id, downloadItem.type),
//               );
//             }
//
//             // Show download button
//             return IconButton(
//               onPressed: onDownload,
//               icon: const Icon(Icons.download),
//               tooltip: 'تحميل',
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// class DownloadManagerTile extends StatelessWidget {
//   const DownloadManagerTile({
//     super.key,
//     required this.downloadItem,
//   });
//
//   final DownloadItem downloadItem;
//
//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.find<DownloaderController>();
//
//     return ListTile(
//       title: Text(
//         downloadItem.title,
//         style: Theme.of(context).textTheme.bodyMedium,
//       ),
//       trailing: SizedBox(
//         width: 100,
//         child: DownloadButton(
//           downloadItem: downloadItem,
//           onDownload: () => controller.startDownload(downloadItem),
//         ),
//       ),
//     );
//   }
// }
//
// // Enhanced section widget for better organization
// class DownloadSection extends StatelessWidget {
//   const DownloadSection({
//     super.key,
//     required this.title,
//     required this.items,
//   });
//
//   final String title;
//   final List<DownloadItem> items;
//
//   @override
//   Widget build(BuildContext context) {
//     if (items.isEmpty) return const SizedBox.shrink();
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Text(
//             title,
//             style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//           ),
//         ),
//         ListView.builder(
//           physics: const NeverScrollableScrollPhysics(),
//           shrinkWrap: true,
//           itemCount: items.length,
//           itemBuilder: (context, index) {
//             return DownloadManagerTile(downloadItem: items[index]);
//           },
//         ),
//         const SizedBox(height: 16),
//       ],
//     );
//   }
// }
