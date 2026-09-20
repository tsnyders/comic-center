import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../browser/browser_fetch.dart';
import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

class AllMangaSource extends MangaSource {
  AllMangaSource([Dio? dio]) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = _apiBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 25)
      ..headers.addAll(_requestHeaders);
  }

  final Dio _dio;

  static const _apiBase = 'https://api.allanime.day';
  // AllManga's old catalogue still works, but its reader moved to MKissa.
  static const _readerBase = 'https://mkissa.to';
  static const _pageTimeout = Duration(seconds: 90);
  static const _coverBase =
      'https://wp.youtube-anime.com/aln.youtube-anime.com';
  static const _defaultPageBase = 'https://ytimgf.youtube-anime.com/';
  static const _pageSize = 26;
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';
  static const _requestHeaders = <String, String>{
    'Origin': 'https://allmanga.to',
    'Referer': 'https://allmanga.to/',
    'User-Agent': _userAgent,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const _mangasQuery = r'''
query($search:SearchInput,$limit:Int,$page:Int,$translationType:VaildTranslationTypeMangaEnumType,$countryOrigin:VaildCountryOriginEnumType){
  mangas(search:$search,limit:$limit,page:$page,translationType:$translationType,countryOrigin:$countryOrigin){
    edges{_id name englishName thumbnail lastChapterInfo}
  }
}
''';

  static const _popularQuery = r'''
query($type:VaildPopularTypeEnumType!,$size:Int!,$page:Int,$dateRange:Int){
  queryPopular(type:$type,size:$size,page:$page,dateRange:$dateRange){
    recommendations{anyCard{_id name englishName thumbnail}}
  }
}
''';

  static const _detailQuery = r'''
query($id:String!){
  manga(_id:$id){
    _id name englishName thumbnail description authors genres status
    availableChaptersDetail lastChapterInfo
  }
}
''';

  static const _chapterPagesHook = r'''
(() => {
  const postChapterPages = (data) => {
    // The site retries this request after its security overlay is solved.
    // Keep capture alive so BrowserHost can show that overlay.
    if (data && Array.isArray(data.errors) && data.errors.some(
      (error) => error && error.message === 'NEED_CAPTCHA'
    )) return;
    if (
      (data && data.chapterPages) ||
      (data && data.data && data.data.chapterPages) ||
      (data && Array.isArray(data.errors) && data.errors.length)
    ) {
      window.yomiAllManga.postMessage(JSON.stringify(data));
    }
  };

  const originalJson = Response.prototype.json;
  Response.prototype.json = function() {
    return originalJson.call(this).then((data) => {
      postChapterPages(data);
      return data;
    });
  };

  const originalParse = JSON.parse;
  JSON.parse = function(...args) {
    const data = originalParse.apply(this, args);
    postChapterPages(data);
    return data;
  };

  // The reader uses a clean iframe realm to parse pages, bypassing our hook.
  // Keep parsing in this document, but preserve real captcha frames.
  const contentWindow = Object.getOwnPropertyDescriptor(
    HTMLIFrameElement.prototype, 'contentWindow'
  ).get;
  const neuter = (element) => {
    if (element.tagName && element.tagName.toUpperCase() === 'IFRAME') {
      Object.defineProperty(element, 'contentWindow', {
        get: () => /^https:\/\/(challenges\.cloudflare\.com|www\.google\.com|www\.recaptcha\.net)\//.test(element.src)
          ? contentWindow.call(element) : null,
        configurable: false,
      });
    }
    return element;
  };
  for (const name of ['createElement', 'createElementNS']) {
    const original = Document.prototype[name];
    Document.prototype[name] = function(...args) {
      return neuter(original.apply(this, args));
    };
  }
})();
''';

  /// Loads the manga page, then navigates to the chapter inside the SPA:
  /// the current reader handles data-href clicks after it mounts.
  static String _chapterNavigationScript(String chapterPath) => '''
(() => {
  const go = () => {
    const a = document.createElement('a');
    a.href = a.dataset.href = '$chapterPath';
    document.body.append(a);
    a.click();
    a.remove();
  };
  let attempts = 0;
  const check = () => {
    if (document.querySelector('[data-href]')) {
      go();
    } else if (attempts++ < 300) {
      setTimeout(check, 50);
    }
  };
  check();
})();
''';

  @override
  String get id => 'all_manga_en';

  @override
  String get name => 'AllManga';

  @override
  String get baseUrl => 'https://allmanga.to';

  @override
  String get language => 'en';

  @override
  String get version => '1.0.0';

  @override
  Uint8List get iconBytes => Uint8List(0);

  @override
  Map<String, String> get imageHeaders => {
        'Referer': 'https://allmanga.to/',
        'User-Agent': BrowserFetch.instance.userAgent,
      };

  @override
  List<SourceFilter> getFilters() => const [
        SelectFilter(
          name: 'Country origin',
          options: ['All', 'Japan', 'South Korea', 'China'],
          values: ['ALL', 'JP', 'KR', 'CN'],
        ),
        GroupFilter(
          name: 'Content',
          excludable: false,
          items: [TriStateFilter(name: 'Show adult', value: 'allowAdult')],
        ),
      ];

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final data = await _query(_popularQuery, {
      'type': 'manga',
      'size': _pageSize,
      'page': page,
      'dateRange': 7,
    });
    final popular = data['queryPopular'];
    if (popular is! Map) return const [];
    final recommendations = popular['recommendations'];
    if (recommendations is! List) return const [];
    return recommendations
        .whereType<Map>()
        .map((item) => item['anyCard'])
        .whereType<Map>()
        .map(_summary)
        .whereType<MangaSummary>()
        .toList(growable: false);
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _fetchMangas('', page: page, countryOrigin: 'ALL', allowAdult: false);

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) {
    var countryOrigin = 'ALL';
    var allowAdult = false;
    for (final filter in filters) {
      if (filter case SelectFilter(name: 'Country origin')) {
        countryOrigin = filter.value;
      } else if (filter case GroupFilter(name: 'Content')) {
        allowAdult = filter.included.contains('allowAdult');
      }
    }
    return _fetchMangas(
      query,
      page: page,
      countryOrigin: countryOrigin,
      allowAdult: allowAdult,
    );
  }

  Future<List<MangaSummary>> _fetchMangas(
    String query, {
    required int page,
    required String countryOrigin,
    required bool allowAdult,
  }) async {
    final data = await _query(_mangasQuery, {
      'search': {
        'query': query,
        'allowAdult': allowAdult,
        'allowUnknown': false,
        'sortBy': 'Recent',
      },
      'limit': _pageSize,
      'page': page,
      'translationType': 'sub',
      'countryOrigin': countryOrigin,
    });
    final mangas = data['mangas'];
    if (mangas is! Map || mangas['edges'] is! List) return const [];
    return (mangas['edges'] as List)
        .whereType<Map>()
        .map(_summary)
        .whereType<MangaSummary>()
        .toList(growable: false);
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final manga = await _fetchManga(mangaId);
    final authors = manga['authors'];
    final genres = manga['genres'];
    final thumbnail = _string(manga['thumbnail']);
    return MangaDetail(
      id: _string(manga['_id']) ?? mangaId,
      title: _title(manga),
      coverUrl: thumbnail == null ? null : _coverUrl(thumbnail),
      author: authors is List
          ? authors.map(_string).whereType<String>().firstOrNull
          : null,
      description: _string(manga['description']),
      genres: genres is List
          ? genres.map(_string).whereType<String>().toList(growable: false)
          : const [],
      status: _status(_string(manga['status'])),
      url: '$baseUrl/manga/$mangaId',
    );
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final manga = await _fetchManga(mangaId);
    final details = manga['availableChaptersDetail'];
    if (details is! Map || details['sub'] is! List) return const [];
    final chapters = (details['sub'] as List)
        .map(_string)
        .whereType<String>()
        .where((chapter) => chapter.isNotEmpty)
        .map(
          (chapter) => ChapterInfo(
            id: '$mangaId|$chapter',
            title: 'Chapter $chapter',
            number: double.tryParse(chapter),
            language: 'en',
            url: '$baseUrl/manga/$mangaId/chapter-$chapter-sub',
          ),
        )
        .toList();
    chapters.sort((a, b) => (b.number ?? double.negativeInfinity)
        .compareTo(a.number ?? double.negativeInfinity));
    return chapters;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final separator = chapterId.indexOf('|');
    if (separator <= 0 || separator == chapterId.length - 1) {
      throw Exception('AllManga chapter ID is invalid.');
    }
    final mangaId = chapterId.substring(0, separator);
    final chapterString = chapterId.substring(separator + 1);
    final mangaPage = Uri.parse('$_readerBase/manga/$mangaId');
    final navigate =
        _chapterNavigationScript('/manga/$mangaId/chapter-$chapterString-sub');

    // ponytail: chapter data is produced by the site's JavaScript, so page
    // discovery is unavailable on Windows and in background isolates.
    Map<String, dynamic> payload;
    try {
      payload = await BrowserFetch.instance.capture(
        mangaPage,
        jsHook: _chapterPagesHook,
        channel: 'yomiAllManga',
        afterLoad: navigate,
        timeout: _pageTimeout,
      );
      if (_graphQlError(payload) != null) {
        payload = await BrowserFetch.instance.capture(
          mangaPage,
          jsHook: _chapterPagesHook,
          channel: 'yomiAllManga',
          afterLoad: navigate,
          timeout: _pageTimeout,
          interactive: true,
        );
      }
    } on BrowserFetchUnavailable {
      throw Exception('AllManga pages need the in-app browser (Android).');
    } on BrowserChallengeCancelled {
      throw Exception('Site check cancelled.');
    }

    final error = _graphQlError(payload);
    if (error != null) throw Exception('AllManga pages: $error');
    final envelope = payload['data'];
    final chapterPages = payload['chapterPages'] ??
        (envelope is Map ? envelope['chapterPages'] : null);
    if (chapterPages is! Map || chapterPages['edges'] is! List) {
      throw Exception('AllManga returned no pages for chapter $chapterString.');
    }
    final edges = chapterPages['edges'] as List;
    final edge = edges.firstOrNull;
    if (edge is Map && edge['pictureUrls'] is List) {
      // The site's own query names the image host serverUrl; older payloads
      // used pictureUrlHead.
      final head =
          _string(edge['serverUrl']) ?? _string(edge['pictureUrlHead']);
      final urls = <String>[];
      for (final picture in (edge['pictureUrls'] as List).whereType<Map>()) {
        final path = _string(picture['url']);
        if (path == null || path.isEmpty) continue;
        urls.add(_pageUrl(head, path));
      }
      if (urls.isNotEmpty) return urls;
    }
    throw Exception('AllManga returned no pages for chapter $chapterString.');
  }

  Future<Map<String, Object?>> _fetchManga(String mangaId) async {
    final data = await _query(_detailQuery, {'id': mangaId});
    final manga = data['manga'];
    if (manga is! Map) {
      throw Exception('AllManga returned no details for this title.');
    }
    return manga.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, Object?>> _query(
    String query,
    Map<String, Object?> variables,
  ) async {
    final response = await _dio.post<Object?>(
      '/api',
      data: {'query': query, 'variables': variables},
    );
    final body = response.data;
    if (body is! Map) {
      throw Exception('AllManga API returned an invalid response.');
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? _string(first['message']) : _string(first);
      throw Exception('AllManga API: ${message ?? 'unknown error'}');
    }
    final data = body['data'];
    if (data is! Map) {
      throw Exception('AllManga API returned no data.');
    }
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  MangaSummary? _summary(Map<Object?, Object?> manga) {
    final id = _string(manga['_id']);
    if (id == null || id.isEmpty) return null;
    final thumbnail = _string(manga['thumbnail']);
    return MangaSummary(
      id: id,
      title: _title(manga),
      coverUrl: thumbnail == null ? null : _coverUrl(thumbnail),
      url: '$baseUrl/manga/$id',
    );
  }

  String _title(Map<Object?, Object?> manga) =>
      _nonEmpty(manga['englishName']) ??
      _nonEmpty(manga['name']) ??
      'Unknown title';

  String _coverUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    return '$_coverBase/${value.replaceFirst(RegExp(r'^/+'), '')}?w=250';
  }

  static String _pageUrl(String? head, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('//')) return 'https:$path';
    var normalizedHead = head == null || head.isEmpty ? _defaultPageBase : head;
    if (normalizedHead.startsWith('//')) {
      normalizedHead = 'https:$normalizedHead';
    } else if (!normalizedHead.startsWith('http://') &&
        !normalizedHead.startsWith('https://')) {
      normalizedHead = 'https://$normalizedHead';
    }
    return '${normalizedHead.replaceFirst(RegExp(r'/+$'), '')}/'
        '${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static String? _graphQlError(Map<String, dynamic> payload) {
    final errors = payload['errors'];
    if (errors is! List || errors.isEmpty) return null;
    final first = errors.first;
    return first is Map
        ? _string(first['message']) ?? 'unknown error'
        : _string(first) ?? 'unknown error';
  }

  static String _status(String? value) => switch (value?.toLowerCase()) {
        'releasing' || 'ongoing' => 'ongoing',
        'finished' || 'completed' => 'completed',
        'hiatus' => 'hiatus',
        'cancelled' || 'canceled' => 'cancelled',
        _ => 'unknown',
      };

  static String? _nonEmpty(Object? value) {
    final string = _string(value);
    return string == null || string.isEmpty ? null : string;
  }

  static String? _string(Object? value) => value?.toString().trim();
}
