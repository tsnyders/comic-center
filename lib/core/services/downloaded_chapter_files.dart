import 'dart:io';

/// Only fully-renamed page files are readable. Temporary `.part` files are
/// deliberately excluded so an interrupted download can never look complete.
final RegExp _downloadedPageName = RegExp(
  r'^page_\d{4}\.(?:gif|jpe?g|png|webp)$',
  caseSensitive: false,
);

Future<List<String>> findDownloadedPagePaths(String directoryPath) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) return const [];

  final pages = <String>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (_downloadedPageName.hasMatch(name) && await entity.length() > 0) {
      pages.add(entity.path);
    }
  }
  pages.sort();
  return pages;
}

Future<List<String>> resolveChapterPagePaths({
  required String? downloadPath,
  required bool isMarkedDownloaded,
  required int expectedPageCount,
  required Future<List<String>> Function() fetchNetworkPages,
}) async {
  if (downloadPath != null || isMarkedDownloaded) {
    final localPages = downloadPath == null
        ? const <String>[]
        : await findDownloadedPagePaths(downloadPath);
    final hasEveryPage = localPages.isNotEmpty &&
        (expectedPageCount <= 0 || localPages.length == expectedPageCount);
    if (hasEveryPage) return localPages;

    // A chapter marked as downloaded must never silently consume data. A
    // missing/corrupt local copy is surfaced so the user can re-download it.
    if (isMarkedDownloaded) {
      throw const FileSystemException(
        'Downloaded chapter files are missing or incomplete. '
        'Remove and download the chapter again.',
      );
    }
  }

  return fetchNetworkPages();
}

String downloadedPageExtension(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.png')) return '.png';
  if (path.endsWith('.webp')) return '.webp';
  if (path.endsWith('.gif')) return '.gif';
  if (path.endsWith('.jpeg')) return '.jpeg';
  return '.jpg';
}

File localPageFile(String path) {
  if (path.startsWith('file://')) return File.fromUri(Uri.parse(path));
  return File(path);
}
