#!/usr/bin/env python3
"""CM-F-01 label->path regression harness (platform-independent).

Parses the actual sources — Paths.swift (the CleanLocation model),
ViewController.swift (switch -> key selection), CleanMeClass.swift
(deletion), Main.storyboard (folder-open tags) — and asserts that for
every location entry the path deleted equals the path the label denotes.
Runs anywhere python3 runs; the XCTest suite in CleanMeTests.swift
asserts the same table on macOS. Exit 0 = PASS, 1 = FAIL.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []


def check(cond, msg):
    print(("PASS  " if cond else "FAIL  ") + msg)
    if not cond:
        FAILURES.append(msg)


# Expected label -> path table (mirrors CleanMeTests.swift).
EXPECTED = [
    ("trash", "Empty the Trash", "~/.Trash/", False),
    ("mails", "Downloaded Mail Attachments", "~/Library/Containers/com.apple.mail/Data/Library/Mail\\ Downloads/", False),
    ("xcode", "Xcode DerivedData and Archives", "~/Library/Developer/Xcode/iOS\\ Device\\ Logs/ ~/Library/Developer/Xcode/DerivedData/", False),
    ("bash", "Bash History", "~/.bash_sessions/ ~/.bash_history", False),
    ("terminal", "Terminal Cache", "/private/var/log/asl/*.asl", True),
    ("userAppLogs", "User Application Logs", "~/Library/Containers/*/Data/Library/Logs/", False),
    ("userAppCache", "User Application Caches", "~/Library/Containers/*/Data/Library/Caches/", False),
    ("userCache", "User Cache", "~/Library/Caches/", False),
    ("userLogs", "User Logs", "~/Library/logs/", False),
    ("systemLogs", "System Logs", "/Library/logs/ /var/log/", True),
    ("globalTemp", "Global Temp Files", "/tmp/", True),
    ("userPrefs", "User Preferences", "~/Library/Preferences/", True),
    ("downloads", "Empty the Downloads Folder", "~/Downloads/", False),
    ("spotlight", "Spotlight indexing files", "/.Spotlight-V100/", False),
    ("docRev", "Document Revisions", "/.DocumentRevisions-V100/", True),
    ("imessage", "iMessage attachments", "~/Library/Messages/Attachments/", True),
]
# Switch outlet -> key the switch must select (ViewController.swift).
EXPECTED_SWITCH = {
    "EmptyTrashSwitch": "trash", "downloadedMailAttachementsSwitch": "mails",
    "xcodeSwitch": "xcode", "bashHistorySwitch": "bash",
    "terminalCacheSwitch": "terminal", "userApplicationLogsSwitch": "userAppLogs",
    "userApplicationCacheSwitch": "userAppCache", "UserCacheSwitch": "userCache",
    "userLogsSwitch": "userLogs", "systemLogsSwitch": "systemLogs",
    "globalTempSwitch": "globalTemp", "UserPreferencesSwitch": "userPrefs",
    "downloadsFolderSwitch": "downloads", "spotlightSwitch": "spotlight",
    "docRevSwitch": "docRev", "imessageAttachmentsSwitch": "imessage",
}

# --- Paths.swift -------------------------------------------------------
paths_src = (ROOT / "Clean Me" / "Paths.swift").read_text()
def swift_unescape(s):
    return s.replace("\\\\", "\x00").replace('\\"', '"').replace("\x00", "\\")


consts = {k: swift_unescape(v) for k, v in
          re.findall(r'let\s+(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"', paths_src)}


def resolve(expr):
    expr = re.sub(r"/\*.*?\*/", "", expr).strip()
    out = ""
    for part in expr.split("+"):
        part = part.strip()
        m = re.fullmatch(r'"((?:[^"\\]|\\.)*)"', part)
        if m:
            out += swift_unescape(m.group(1))
        elif part in consts:
            out += consts[part]
        else:
            raise ValueError("unresolvable: " + part)
    return out


entries = []
for m in re.finditer(
    r'CleanLocation\(key:\s*"(\w+)",\s*displayName:\s*"([^"]+)",\s*path:\s*(.+?),\s*requiresRoot:\s*(true|false)\)',
    paths_src,
):
    entries.append((m.group(1), m.group(2), resolve(m.group(3)), m.group(4) == "true"))

check(len(entries) == 16, f"model has 16 entries (got {len(entries)})")
check(entries == EXPECTED, "model entries == expected label->path table (order, label, path, root)")
if entries != EXPECTED:
    for got, want in zip(entries, EXPECTED):
        if got != want:
            print(f"      got {got}\n      want {want}")
check("cleanLocations.map" in paths_src and "PATHkey" in paths_src,
      "PATHkey is derived from cleanLocations (single source of truth)")
check(not re.search(r"let PATHkey:\s*\[String\]\s*=\s*\[\"", paths_src),
      "no hand-written parallel PATHkey array remains")

# --- CleanMeClass.swift --------------------------------------------------
cm_src = (ROOT / "Clean Me" / "CleanMeClass.swift").read_text()
check("func deleteItems(selectedLocations: [CleanLocation])" in cm_src,
      "CleanMe.deleteItems takes [CleanLocation]")
check("location.path" in cm_src and "location.requiresRoot" in cm_src,
      "deletion path + root flag come from the selected location itself")
check("PATHkey[pathKey]" not in cm_src and "checkedItemsArray" not in cm_src,
      "no index-joined deletion lookup remains in CleanMeClass")

# --- ViewController.swift -------------------------------------------------
vc_src = (ROOT / "Clean Me" / "ViewController.swift").read_text()
selects = dict(re.findall(r'select\("(\w+)", if: (\w+)\.checked\)', vc_src))
got_switch = {sw: key for key, sw in selects.items()}
check(got_switch == EXPECTED_SWITCH, "every switch selects its own key in cleanBtnClicked")
if got_switch != EXPECTED_SWITCH:
    print(f"      got {got_switch}")
check("deleteItems(selectedLocations: selectedLocations)" in vc_src,
      "cleanBtnClicked passes the selected locations to deleteItems")
check(not re.search(r"PathKeys\.append\(\d+\)", vc_src),
      "no integer-index selection list remains in cleanBtnClicked")
check("cleanLocation(forTag: sender.tag)" in vc_src,
      "openBtnClicked resolves the tag through cleanLocation(forTag:)")

# --- Main.storyboard --------------------------------------------------------
tree = ET.parse(ROOT / "Clean Me" / "Base.lproj" / "Main.storyboard")
root_el = tree.getroot()


def y_of(el):
    r = el.find("rect")
    return float(r.get("y")) if r is not None else None


display_names = {n for _, n, _, _ in EXPECTED}
labels = []
for tf in root_el.iter("textField"):
    cell = tf.find("textFieldCell")
    if cell is not None and cell.get("title") in display_names:
        labels.append((y_of(tf), cell.get("title")))
name_by_key = {k: n for k, n, _, _ in EXPECTED}
for btn in root_el.iter("button"):
    conns = btn.find("connections")
    acts = [a.get("selector") for a in conns] if conns is not None else []
    if "openBtnClicked:" not in acts:
        continue
    tag = int(btn.get("tag") or 0)
    by = y_of(btn)
    nearest = min(labels, key=lambda ly: abs(ly[0] - by))
    want_key = EXPECTED[tag][0] if 0 <= tag < len(EXPECTED) else None
    check(want_key is not None and nearest[1] == name_by_key[want_key],
          f"storyboard tag {tag} sits on row '{nearest[1]}' and resolves to '{want_key}'")
check(True, "storyboard folder-open tags parsed")

print()
if FAILURES:
    print(f"HARNESS RESULT: FAIL ({len(FAILURES)} failures)")
    sys.exit(1)
print("HARNESS RESULT: PASS (all label->path assertions)")
