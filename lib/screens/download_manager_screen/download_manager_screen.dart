import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/models/azkar_models.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';
import 'package:yosria/screens/download_manager_screen/downloader_progress_btn.dart';
import 'package:yosria/screens/library_screen/library_screen.dart';

class DownloadManagerPage extends StatelessWidget {
  DownloadManagerPage({super.key, required this.index});
  final int index;

  final dc = Get.put(DownloaderController());
  final collectionKeys = azkarWithNarrations.keys;
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        initialIndex: index,
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة التحميلات'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'الصوتيات'),
                Tab(text: 'الكتب'),
              ],
            ),
          ),
          body: TabBarView(children: [
            SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: collectionKeys.map(
                      (key) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TODO: theme
                            Text(
                              key,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: azkarWithNarrations[key]!.length,
                                itemBuilder: (context, i) {
                                  final zikr = azkarWithNarrations[key]![i];
                                  return DownloadManagerTile(
                                      title: zikr.title,
                                      url: zikr.url!,
                                      directory: 'narrations');
                                })
                          ],
                        );
                      },
                    ).toList(),
                  )),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (String title in booksTitles.keys) ...{
                      DownloadManagerTile(
                          title: title,
                          url: booksTitles[title]!,
                          directory: 'books')
                    }
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class DownloadManagerTile extends StatelessWidget {
  const DownloadManagerTile(
      {super.key,
      required this.title,
      required this.url,
      required this.directory});
  final String title, url, directory;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: SizedBox(
        width: 100,
        child: DownloaderProgressBtn(
          title: title,
          downloadUrl: url,
          directory: directory,
        ),
      ),
    );
  }
}
