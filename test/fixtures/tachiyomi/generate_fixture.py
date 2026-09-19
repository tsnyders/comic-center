"""Rebuild the synthetic fixture with Google's protobuf encoder, not Yomi code.

Run: python test/fixtures/tachiyomi/generate_fixture.py
Requires: protobuf (only for regenerating the committed fixture).
Wire field references: docs/TACHIYOMI_IMPORT.md.
"""
import gzip
from pathlib import Path
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory

schema = descriptor_pb2.FileDescriptorProto(name="migration_fixture.proto", syntax="proto2")
T = descriptor_pb2.FieldDescriptorProto
definitions = {
    "Chapter": [("url", 1, T.TYPE_STRING), ("name", 2, T.TYPE_STRING),
                ("read", 4, T.TYPE_BOOL), ("lastPageRead", 6, T.TYPE_INT64),
                ("number", 9, T.TYPE_FLOAT)],
    "History": [("url", 1, T.TYPE_STRING), ("lastRead", 2, T.TYPE_INT64)],
    "Source": [("name", 1, T.TYPE_STRING), ("id", 2, T.TYPE_INT64)],
    "Category": [("name", 1, T.TYPE_STRING), ("order", 2, T.TYPE_INT64)],
    "Manga": [("source", 1, T.TYPE_INT64), ("url", 2, T.TYPE_STRING),
              ("title", 3, T.TYPE_STRING), ("chapters", 16, "Chapter"),
              ("categories", 17, T.TYPE_INT64), ("favorite", 100, T.TYPE_BOOL),
              ("history", 104, "History")],
    "Backup": [("manga", 1, "Manga"), ("categories", 2, "Category"),
               ("sources", 101, "Source")],
}
for name, fields in definitions.items():
    message = schema.message_type.add(name=name)
    for field_name, number, field_type in fields:
        repeated = (name == "Backup" or
                    (name == "Manga" and field_name in ["chapters", "categories", "history"]))
        field = message.field.add(name=field_name, number=number,
            label=T.LABEL_REPEATED if repeated else T.LABEL_OPTIONAL)
        if isinstance(field_type, str):
            field.type = T.TYPE_MESSAGE
            field.type_name = field_type
        else:
            field.type = field_type

pool = descriptor_pool.DescriptorPool()
pool.Add(schema)
Backup = message_factory.GetMessageClass(pool.FindMessageTypeByName("Backup"))
backup = Backup()
backup.categories.add(name="Manhwa", order=1)
backup.sources.add(name="MangaDex (EN)", id=2499283573021220255)
backup.sources.add(name="Unavailable source (JA)", id=9223372036854775807)
manga = backup.manga.add(source=2499283573021220255, favorite=True,
    url="/title/00000000-0000-4000-8000-000000000001", title="Synthetic manga")
manga.categories.append(1)
manga.chapters.add(url="/chapter/00000000-0000-4000-8000-000000000002",
    name="Chapter 1", number=1.5, lastPageRead=9)
manga.history.add(url=manga.chapters[0].url, lastRead=1700000000000)
unknown = backup.manga.add(source=9223372036854775807, favorite=True,
    url="/series/example", title="Synthetic unavailable comic")
unknown.chapters.add(url="/series/example/1", name="Chapter 1", number=1, read=True)
Path(__file__).with_name("library.tachibk").write_bytes(
    gzip.compress(backup.SerializeToString(), mtime=0))
