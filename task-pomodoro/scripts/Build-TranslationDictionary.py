import argparse
import csv
import re
import struct
from pathlib import Path

WORD_RE = re.compile(r"^[A-Za-z][A-Za-z'\-]*$")
EXAM_TAG_RE = re.compile(r"zk|gk|cet4|cet6|ky|toefl|ielts|gre", re.I)
INDEX_MAGIC = b"TPDK2"
INDEX_RECORD = struct.Struct("<IHqi")
GUARANTEED_WORDS = {
    "public", "private", "protected", "class", "method", "example", "translation", "translate", "document",
    "true", "false", "return", "value", "function", "variable", "constant", "object", "string", "number",
    "boolean", "null", "none", "error", "warning", "message", "request", "response", "source", "target",
    "result", "setting", "option", "default", "current", "previous", "next", "create", "update", "delete",
    "read", "write", "copy", "paste", "select", "selection", "word", "sentence", "text", "window",
    "screen", "focus", "control", "event", "action", "button", "menu", "service", "provider", "endpoint",
    "api", "local", "online", "cache", "memory", "timer", "thread", "process", "application", "system",
    "user", "file", "path", "line", "page", "data", "model", "view", "test", "check",
    "valid", "invalid", "available", "unavailable", "open", "close", "start", "stop", "save", "load",
    "find", "search", "match", "filter", "sort", "group", "parse", "build", "run", "if",
    "else", "for", "while", "try", "catch", "finally", "and", "or", "not", "is",
    "are", "be", "have", "has", "can", "should", "because", "however", "therefore", "this",
    "that", "these", "those",
}


def as_int(value, default=0):
    try:
        if value is None or value == "":
            return default
        return int(float(str(value).strip()))
    except Exception:
        return default


def clean(value):
    return (value or "").replace("\t", " ").replace("\r\n", "\\n").replace("\n", "\\n").replace("\r", "\\n").strip()


def frequency_label(bnc, frq):
    if 0 < bnc < 999999:
        return f"bnc:{bnc}"
    if 0 < frq < 999999:
        return f"frq:{frq}"
    return ""


def score_row(row, word):
    collins = as_int(row.get("collins"), 0)
    bnc = as_int(row.get("bnc"), 999999)
    frq = as_int(row.get("frq"), 999999)
    tag = row.get("tag") or ""
    score = 0
    if (row.get("oxford") or "").strip() == "1":
        score += 100000
    if collins > 0:
        score += 50000 + collins * 1000
    if EXAM_TAG_RE.search(tag):
        score += 30000
    if 0 < bnc < 999999:
        score += max(0, 30000 - bnc)
    if 0 < frq < 999999:
        score += max(0, 30000 - frq)
    if word in GUARANTEED_WORDS:
        score += 1000000
    return score, bnc, frq


def build_dictionary(ecdict_csv, output_path, max_words, include_all=False):
    best = {}
    rows_seen = 0
    with ecdict_csv.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            rows_seen += 1
            raw_word = (row.get("word") or "").strip()
            word = raw_word.lower()
            translation = clean(row.get("translation"))
            if not raw_word or not translation or not WORD_RE.match(raw_word):
                continue
            score, bnc, frq = score_row(row, word)
            if score <= 0 and not include_all:
                continue
            item = (
                score,
                word,
                clean(row.get("phonetic")),
                clean(row.get("pos")),
                translation,
                clean(row.get("tag")),
                frequency_label(bnc, frq),
                clean(row.get("exchange")),
            )
            previous = best.get(word)
            if previous is None or score > previous[0]:
                best[word] = item

    selected = sorted(best.values(), key=lambda item: (-item[0], item[1]))
    if max_words > 0:
        selected = selected[:max_words]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8-sig", newline="\n") as handle:
        handle.write("word\tphonetic\tpos\ttranslation\ttags\tfrequency\texchange\n")
        for _, word, phonetic, pos, translation, tags, frequency, exchange in selected:
            handle.write(f"{word}\t{phonetic}\t{pos}\t{translation}\t{tags}\t{frequency}\t{exchange}\n")
    return rows_seen, len(selected), output_path.stat().st_size, [word for word in sorted(GUARANTEED_WORDS) if word not in best]


def build_dictionary_index(tsv_path):
    entries = {}
    size = tsv_path.stat().st_size
    with tsv_path.open("rb") as handle:
        while True:
            offset = handle.tell()
            raw_line = handle.readline()
            if not raw_line:
                break
            line = raw_line.rstrip(b"\r\n")
            if not line:
                continue
            word_line = line[3:] if line.startswith(b"\xef\xbb\xbf") else line
            stripped = word_line.lstrip()
            if not stripped or stripped.startswith(b"#"):
                continue
            word_bytes = stripped.split(b"\t", 1)[0].strip()
            try:
                word = word_bytes.decode("utf-8").lower()
            except UnicodeDecodeError:
                continue
            if not word or word == "word" or word in entries:
                continue
            entries[word] = (offset, len(line))

    records = bytearray()
    word_blob = bytearray()
    for word, (offset, length) in sorted(entries.items()):
        encoded = word.encode("utf-8")
        if len(encoded) > 65535:
            continue
        word_offset = len(word_blob)
        word_blob.extend(encoded)
        records.extend(INDEX_RECORD.pack(word_offset, len(encoded), offset, length))
    index_path = tsv_path.with_name(tsv_path.name + ".idx")
    with index_path.open("wb") as handle:
        handle.write(INDEX_MAGIC)
        handle.write(struct.pack("<qii", size, len(records) // INDEX_RECORD.size, len(word_blob)))
        handle.write(records)
        handle.write(word_blob)
    return len(records) // INDEX_RECORD.size, index_path.stat().st_size, index_path


def main():
    parser = argparse.ArgumentParser(description="Build the blur translation TSV dictionary from ECDICT CSV.")
    parser.add_argument("--ecdict-csv", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--max-words", type=int, default=50000)
    parser.add_argument("--include-all", action="store_true", help="Include all valid ECDICT word rows with translations instead of only scored core rows.")
    args = parser.parse_args()
    if not args.ecdict_csv.is_file():
        raise SystemExit(f"ECDICT csv not found: {args.ecdict_csv}")
    rows_seen, selected, size, missing = build_dictionary(args.ecdict_csv, args.output, args.max_words, args.include_all)
    index_entries, index_size, index_path = build_dictionary_index(args.output)
    print(f"rows_seen={rows_seen} selected={selected} bytes={size} output={args.output}")
    print(f"index_entries={index_entries} index_bytes={index_size} index_output={index_path}")
    if missing:
        print("missing_guaranteed=" + ",".join(missing))


if __name__ == "__main__":
    main()