// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMangaEntryCollection on Isar {
  IsarCollection<MangaEntry> get mangaEntrys => this.collection();
}

const MangaEntrySchema = CollectionSchema(
  name: r'MangaEntry',
  id: -2498067705662673485,
  properties: {
    r'addedToLibrary': PropertySchema(
      id: 0,
      name: r'addedToLibrary',
      type: IsarType.dateTime,
    ),
    r'artist': PropertySchema(
      id: 1,
      name: r'artist',
      type: IsarType.string,
    ),
    r'author': PropertySchema(
      id: 2,
      name: r'author',
      type: IsarType.string,
    ),
    r'categories': PropertySchema(
      id: 3,
      name: r'categories',
      type: IsarType.stringList,
    ),
    r'chapterCount': PropertySchema(
      id: 4,
      name: r'chapterCount',
      type: IsarType.long,
    ),
    r'coverUrl': PropertySchema(
      id: 5,
      name: r'coverUrl',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 6,
      name: r'description',
      type: IsarType.string,
    ),
    r'genres': PropertySchema(
      id: 7,
      name: r'genres',
      type: IsarType.stringList,
    ),
    r'inLibrary': PropertySchema(
      id: 8,
      name: r'inLibrary',
      type: IsarType.bool,
    ),
    r'lastReadAt': PropertySchema(
      id: 9,
      name: r'lastReadAt',
      type: IsarType.dateTime,
    ),
    r'lastReadChapterId': PropertySchema(
      id: 10,
      name: r'lastReadChapterId',
      type: IsarType.string,
    ),
    r'lastReadChapterNumber': PropertySchema(
      id: 11,
      name: r'lastReadChapterNumber',
      type: IsarType.double,
    ),
    r'lastReadPage': PropertySchema(
      id: 12,
      name: r'lastReadPage',
      type: IsarType.long,
    ),
    r'lastUpdated': PropertySchema(
      id: 13,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'sourceId': PropertySchema(
      id: 14,
      name: r'sourceId',
      type: IsarType.string,
    ),
    r'sourceKey': PropertySchema(
      id: 15,
      name: r'sourceKey',
      type: IsarType.string,
    ),
    r'sourceMangaId': PropertySchema(
      id: 16,
      name: r'sourceMangaId',
      type: IsarType.string,
    ),
    r'sourceUrl': PropertySchema(
      id: 17,
      name: r'sourceUrl',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 18,
      name: r'status',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 19,
      name: r'title',
      type: IsarType.string,
    ),
    r'unreadCount': PropertySchema(
      id: 20,
      name: r'unreadCount',
      type: IsarType.long,
    )
  },
  estimateSize: _mangaEntryEstimateSize,
  serialize: _mangaEntrySerialize,
  deserialize: _mangaEntryDeserialize,
  deserializeProp: _mangaEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'title': IndexSchema(
      id: -7636685945352118059,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'sourceKey': IndexSchema(
      id: 5622660045965472999,
      name: r'sourceKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'sourceKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'genres': IndexSchema(
      id: 7272600453950102276,
      name: r'genres',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'genres',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'inLibrary': IndexSchema(
      id: -9031959425681481226,
      name: r'inLibrary',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'inLibrary',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _mangaEntryGetId,
  getLinks: _mangaEntryGetLinks,
  attach: _mangaEntryAttach,
  version: '3.1.0+1',
);

int _mangaEntryEstimateSize(
  MangaEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.artist;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.author;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.categories.length * 3;
  {
    for (var i = 0; i < object.categories.length; i++) {
      final value = object.categories[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.coverUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.genres.length * 3;
  {
    for (var i = 0; i < object.genres.length; i++) {
      final value = object.genres[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.lastReadChapterId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sourceId.length * 3;
  bytesCount += 3 + object.sourceKey.length * 3;
  bytesCount += 3 + object.sourceMangaId.length * 3;
  bytesCount += 3 + object.sourceUrl.length * 3;
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _mangaEntrySerialize(
  MangaEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.addedToLibrary);
  writer.writeString(offsets[1], object.artist);
  writer.writeString(offsets[2], object.author);
  writer.writeStringList(offsets[3], object.categories);
  writer.writeLong(offsets[4], object.chapterCount);
  writer.writeString(offsets[5], object.coverUrl);
  writer.writeString(offsets[6], object.description);
  writer.writeStringList(offsets[7], object.genres);
  writer.writeBool(offsets[8], object.inLibrary);
  writer.writeDateTime(offsets[9], object.lastReadAt);
  writer.writeString(offsets[10], object.lastReadChapterId);
  writer.writeDouble(offsets[11], object.lastReadChapterNumber);
  writer.writeLong(offsets[12], object.lastReadPage);
  writer.writeDateTime(offsets[13], object.lastUpdated);
  writer.writeString(offsets[14], object.sourceId);
  writer.writeString(offsets[15], object.sourceKey);
  writer.writeString(offsets[16], object.sourceMangaId);
  writer.writeString(offsets[17], object.sourceUrl);
  writer.writeString(offsets[18], object.status);
  writer.writeString(offsets[19], object.title);
  writer.writeLong(offsets[20], object.unreadCount);
}

MangaEntry _mangaEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MangaEntry();
  object.addedToLibrary = reader.readDateTimeOrNull(offsets[0]);
  object.artist = reader.readStringOrNull(offsets[1]);
  object.author = reader.readStringOrNull(offsets[2]);
  object.categories = reader.readStringList(offsets[3]) ?? [];
  object.chapterCount = reader.readLong(offsets[4]);
  object.coverUrl = reader.readStringOrNull(offsets[5]);
  object.description = reader.readStringOrNull(offsets[6]);
  object.genres = reader.readStringList(offsets[7]) ?? [];
  object.id = id;
  object.inLibrary = reader.readBool(offsets[8]);
  object.lastReadAt = reader.readDateTimeOrNull(offsets[9]);
  object.lastReadChapterId = reader.readStringOrNull(offsets[10]);
  object.lastReadChapterNumber = reader.readDoubleOrNull(offsets[11]);
  object.lastReadPage = reader.readLong(offsets[12]);
  object.lastUpdated = reader.readDateTimeOrNull(offsets[13]);
  object.sourceId = reader.readString(offsets[14]);
  object.sourceKey = reader.readString(offsets[15]);
  object.sourceMangaId = reader.readString(offsets[16]);
  object.sourceUrl = reader.readString(offsets[17]);
  object.status = reader.readString(offsets[18]);
  object.title = reader.readString(offsets[19]);
  object.unreadCount = reader.readLong(offsets[20]);
  return object;
}

P _mangaEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readDoubleOrNull(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mangaEntryGetId(MangaEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mangaEntryGetLinks(MangaEntry object) {
  return [];
}

void _mangaEntryAttach(IsarCollection<dynamic> col, Id id, MangaEntry object) {
  object.id = id;
}

extension MangaEntryByIndex on IsarCollection<MangaEntry> {
  Future<MangaEntry?> getBySourceKey(String sourceKey) {
    return getByIndex(r'sourceKey', [sourceKey]);
  }

  MangaEntry? getBySourceKeySync(String sourceKey) {
    return getByIndexSync(r'sourceKey', [sourceKey]);
  }

  Future<bool> deleteBySourceKey(String sourceKey) {
    return deleteByIndex(r'sourceKey', [sourceKey]);
  }

  bool deleteBySourceKeySync(String sourceKey) {
    return deleteByIndexSync(r'sourceKey', [sourceKey]);
  }

  Future<List<MangaEntry?>> getAllBySourceKey(List<String> sourceKeyValues) {
    final values = sourceKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'sourceKey', values);
  }

  List<MangaEntry?> getAllBySourceKeySync(List<String> sourceKeyValues) {
    final values = sourceKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sourceKey', values);
  }

  Future<int> deleteAllBySourceKey(List<String> sourceKeyValues) {
    final values = sourceKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sourceKey', values);
  }

  int deleteAllBySourceKeySync(List<String> sourceKeyValues) {
    final values = sourceKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sourceKey', values);
  }

  Future<Id> putBySourceKey(MangaEntry object) {
    return putByIndex(r'sourceKey', object);
  }

  Id putBySourceKeySync(MangaEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'sourceKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySourceKey(List<MangaEntry> objects) {
    return putAllByIndex(r'sourceKey', objects);
  }

  List<Id> putAllBySourceKeySync(List<MangaEntry> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sourceKey', objects, saveLinks: saveLinks);
  }
}

extension MangaEntryQueryWhereSort
    on QueryBuilder<MangaEntry, MangaEntry, QWhere> {
  QueryBuilder<MangaEntry, MangaEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhere> anyInLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'inLibrary'),
      );
    });
  }
}

extension MangaEntryQueryWhere
    on QueryBuilder<MangaEntry, MangaEntry, QWhereClause> {
  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> titleEqualTo(
      String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'title',
        value: [title],
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> titleNotEqualTo(
      String title) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> sourceKeyEqualTo(
      String sourceKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sourceKey',
        value: [sourceKey],
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> sourceKeyNotEqualTo(
      String sourceKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceKey',
              lower: [],
              upper: [sourceKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceKey',
              lower: [sourceKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceKey',
              lower: [sourceKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceKey',
              lower: [],
              upper: [sourceKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> genresEqualTo(
      List<String> genres) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'genres',
        value: [genres],
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> genresNotEqualTo(
      List<String> genres) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'genres',
              lower: [],
              upper: [genres],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'genres',
              lower: [genres],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'genres',
              lower: [genres],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'genres',
              lower: [],
              upper: [genres],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> inLibraryEqualTo(
      bool inLibrary) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'inLibrary',
        value: [inLibrary],
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterWhereClause> inLibraryNotEqualTo(
      bool inLibrary) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'inLibrary',
              lower: [],
              upper: [inLibrary],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'inLibrary',
              lower: [inLibrary],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'inLibrary',
              lower: [inLibrary],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'inLibrary',
              lower: [],
              upper: [inLibrary],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MangaEntryQueryFilter
    on QueryBuilder<MangaEntry, MangaEntry, QFilterCondition> {
  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedToLibrary',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedToLibrary',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedToLibrary',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedToLibrary',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedToLibrary',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      addedToLibraryBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedToLibrary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'artist',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      artistIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'artist',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'artist',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'artist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'artist',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> artistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artist',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      artistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'artist',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'author',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      authorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'author',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'author',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'author',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'author',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'author',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'categories',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'categories',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categories',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'categories',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      categoriesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      chapterCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      chapterCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      chapterCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      chapterCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chapterCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coverUrl',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      coverUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coverUrl',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      coverUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coverUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      coverUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> coverUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coverUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      coverUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      coverUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coverUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'genres',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'genres',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'genres',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genres',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'genres',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> genresIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      genresLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> inLibraryEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inLibrary',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastReadAt',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastReadAt',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> lastReadAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> lastReadAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReadAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastReadChapterId',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastReadChapterId',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReadChapterId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastReadChapterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastReadChapterId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadChapterId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastReadChapterId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastReadChapterNumber',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastReadChapterNumber',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadChapterNumber',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReadChapterNumber',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReadChapterNumber',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadChapterNumberBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReadChapterNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadPageEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadPage',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadPageGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReadPage',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadPageLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReadPage',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastReadPageBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReadPage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUpdated',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUpdated',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      lastUpdatedBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdated',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceMangaId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceMangaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceMangaId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceMangaId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceMangaIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceMangaId',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> sourceUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      sourceUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      unreadCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      unreadCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      unreadCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterFilterCondition>
      unreadCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unreadCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MangaEntryQueryObject
    on QueryBuilder<MangaEntry, MangaEntry, QFilterCondition> {}

extension MangaEntryQueryLinks
    on QueryBuilder<MangaEntry, MangaEntry, QFilterCondition> {}

extension MangaEntryQuerySortBy
    on QueryBuilder<MangaEntry, MangaEntry, QSortBy> {
  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByAddedToLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToLibrary', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      sortByAddedToLibraryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToLibrary', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByInLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inLibrary', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByInLibraryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inLibrary', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastReadChapterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      sortByLastReadChapterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      sortByLastReadChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterNumber', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      sortByLastReadChapterNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterNumber', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastReadPage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadPage', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastReadPageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadPage', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceMangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceMangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortBySourceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> sortByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }
}

extension MangaEntryQuerySortThenBy
    on QueryBuilder<MangaEntry, MangaEntry, QSortThenBy> {
  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByAddedToLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToLibrary', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      thenByAddedToLibraryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToLibrary', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByInLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inLibrary', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByInLibraryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inLibrary', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastReadChapterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      thenByLastReadChapterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      thenByLastReadChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterNumber', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy>
      thenByLastReadChapterNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadChapterNumber', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastReadPage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadPage', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastReadPageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadPage', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceMangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceMangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenBySourceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QAfterSortBy> thenByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }
}

extension MangaEntryQueryWhereDistinct
    on QueryBuilder<MangaEntry, MangaEntry, QDistinct> {
  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByAddedToLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedToLibrary');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByArtist(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artist', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByAuthor(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'author', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByCategories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categories');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chapterCount');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByCoverUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByGenres() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genres');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByInLibrary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inLibrary');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReadAt');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByLastReadChapterId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReadChapterId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct>
      distinctByLastReadChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReadChapterNumber');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByLastReadPage() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReadPage');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctBySourceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctBySourceKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctBySourceMangaId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceMangaId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctBySourceUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaEntry, MangaEntry, QDistinct> distinctByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unreadCount');
    });
  }
}

extension MangaEntryQueryProperty
    on QueryBuilder<MangaEntry, MangaEntry, QQueryProperty> {
  QueryBuilder<MangaEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MangaEntry, DateTime?, QQueryOperations>
      addedToLibraryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedToLibrary');
    });
  }

  QueryBuilder<MangaEntry, String?, QQueryOperations> artistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artist');
    });
  }

  QueryBuilder<MangaEntry, String?, QQueryOperations> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'author');
    });
  }

  QueryBuilder<MangaEntry, List<String>, QQueryOperations>
      categoriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categories');
    });
  }

  QueryBuilder<MangaEntry, int, QQueryOperations> chapterCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chapterCount');
    });
  }

  QueryBuilder<MangaEntry, String?, QQueryOperations> coverUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverUrl');
    });
  }

  QueryBuilder<MangaEntry, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<MangaEntry, List<String>, QQueryOperations> genresProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genres');
    });
  }

  QueryBuilder<MangaEntry, bool, QQueryOperations> inLibraryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inLibrary');
    });
  }

  QueryBuilder<MangaEntry, DateTime?, QQueryOperations> lastReadAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReadAt');
    });
  }

  QueryBuilder<MangaEntry, String?, QQueryOperations>
      lastReadChapterIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReadChapterId');
    });
  }

  QueryBuilder<MangaEntry, double?, QQueryOperations>
      lastReadChapterNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReadChapterNumber');
    });
  }

  QueryBuilder<MangaEntry, int, QQueryOperations> lastReadPageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReadPage');
    });
  }

  QueryBuilder<MangaEntry, DateTime?, QQueryOperations> lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> sourceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceId');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> sourceKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceKey');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> sourceMangaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceMangaId');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> sourceUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceUrl');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<MangaEntry, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<MangaEntry, int, QQueryOperations> unreadCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unreadCount');
    });
  }
}
