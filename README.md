# Character Tracker — KOReader Plugin

Track characters, relationships, and notes while you read.
Never forget who's who in a long novel — or across an entire series — again.

> **This is a fork** of [Shac0x/charactertracker.koplugin](https://github.com/Shac0x/charactertracker.koplugin),
> the original plugin by Shac0x. The changes below are also open as pull
> requests there.

### What this fork adds

- **Sidecar storage**: characters live in the book's `.sdr` folder and move
  with the book.
- **Export / import**: a JSON copy for a synced folder or notes vault (git,
  Syncthing…), merged back with edits made on a PC.
- **Character button in the dictionary popup** and **Add as alias of…**:
  link nicknames to a known character in two taps.
- **Whole-word matching**: "Tom" no longer underlines "Tomorrow".
- **Cached name index**: books open without re-indexing; only new names are
  searched.
- **Lighter underline**: thin gray, or only the first mention on each page.
- **Translations**: follows KOReader's UI language; Turkish included.

---

## Features

### Characters
- **Add characters on the fly** from the highlight popup or the Tools menu.
- **Aliases** — track nicknames, titles, house names, alternate spellings.
- **Notes** — add evolving observations as the story progresses; edit or delete any time.
- **Rating** — rate characters from ★ to ★★★★★.
- **Role** — tag as Main, Secondary, Tertiary, Mentioned, Antagonist, or Narrator.
- **Rename** — safely rename a character (relationships pointing to it are updated automatically).

### Relationships
- Link characters with predefined types: **father, mother, son, daughter, brother, sister, spouse, ally, enemy, friend, mentor, servant, master, lover**.
- **Custom relationships** for anything else (squire, rival, betrothed, ...).
- Detail view shows both **outgoing** (→) and **incoming** (←) relationships.
- Tap a relationship to jump to that character's detail view.
- Deleting a character cleans up dangling relationships automatically.

### In-text recognition
- **Underline character names** in the page (toggle in the menu).
  Names and aliases are indexed in the background using KOReader's `findAllText`.
- **Underline style**: thick (KOReader's underline), thin light gray, or thin
  under only the first mention of each character on the page. The other
  mentions are not underlined but can still be tapped.
- **Tap any underlined name** to open that character's detail view instantly.
- Re-indexes automatically when characters or aliases are added/edited.

### Highlight and dictionary integration
- Adds a **Character** button to the highlight popup and to the dictionary
  popup (so a single long-pressed word works too). In the dictionary popup it
  can be moved or hidden with *Dictionary settings → Customize buttons*.
- Selecting a name and tapping **Character**:
  - opens that character if the name or one of its aliases is already known;
  - otherwise offers **New character** or **Add as alias of…**, so a
    nickname, diminutive or title (Vasenka, Vasya, Sassata…) can be linked to
    a known character in two taps.
- The whole selection is used as the name, cleaned up: surrounding
  punctuation and a possessive or case suffix after an apostrophe are dropped
  ("Wenjie’nin" → "Wenjie", "Holmes's" → "Holmes"; "O'Brien" is kept).
- **Match whole words only** (on by default): a name is underlined only as a
  whole word, so "Tom" does not match "Tomorrow" and "Wang" does not match
  "Wangfujing". A suffix after an apostrophe still matches ("Berk’in",
  "Holmes's"). Turn it off to match inside words too, e.g. to use a stem like
  "Vasenk" for "Vasenka", "Vasenku"; otherwise add each form as an alias.

### Series support (shared characters across books)
- **Link a book to a series** to share one character database across multiple books.
- When linking, existing book characters are **merged** into the series
  (aliases and notes are deduplicated).
- **Unlink** at any time — the series file is preserved.
- Manage and **delete** series from the link dialog.
- Perfect for *A Song of Ice and Fire*, *The Wheel of Time*, *Discworld*, etc.

---

## Installation

1. Download `charactertracker.koplugin.zip` from the
   [latest release](https://github.com/phobo3s/charactertracker.koplugin/releases/latest).
2. Unzip it into your KOReader plugins directory, so that you get:

   ```
   <koreader>/plugins/charactertracker.koplugin/
   ```

   If you had the original plugin installed, replace that folder.
3. Restart KOReader.

Characters saved by the original plugin are read as they are and moved to the
book's sidecar folder on the next save.

---

## Usage

### Adding a character

**From the highlight popup (recommended):**
1. Long-press a name: the dictionary popup has a **Character** button
   (it reads **Character: <name>** when the word is already known, and opens
   that character). For a multi-word selection, hold and drag, then tap
   **Character** in the highlight popup.
2. Tap **Character**.
3. Choose **New character** and confirm the name (with an optional first
   note), or **Add as alias of…**, pick the character and confirm the alias
   (editable before saving).

**From the Tools menu:**
1. **Tools → Character Tracker → Add character**
2. Enter name and optional note.

### Viewing & editing a character

1. **Tools → Character Tracker → Character list**
2. Tap a character to open the detail view.
3. From there: rate, set role, manage notes, manage aliases, manage relationships, rename, or delete.

### Underlining names in the text

1. **Tools → Character Tracker → Underline names in text** (toggle).
2. Tap any underlined name to open its detail view.

> Indexing runs once when the setting changes or when you add/edit characters.
> A dismissible progress dialog is shown.

### Linking a book to a series

1. **Tools → Character Tracker → Link to series**
2. Pick an existing series or create a new one.
3. Existing characters in the current book are merged into the shared series file.

To unlink: open the same menu entry and choose **Unlink from series**.

---

## Data storage

- **Per-book mode** (default): characters are stored as
  `characters.json` in the book's sidecar folder (`<book>.sdr/`), so they
  follow KOReader's *Book metadata location* setting and move with the book.
  A `<book_path>.characters.json` file from older versions is still read and
  moved to the sidecar folder on the next save.
- **Series mode**: characters are stored in
  `<koreader-data>/character_tracker/<series_name>.json`
  and shared by every book linked to that series.

The format is plain JSON — easy to back up, version-control, or edit by hand.

---

## Export / import (sync with a notes vault)

**Tools → Character Tracker → Export / import** works like KOReader's own
annotation export (*Bookmarks → Export annotations on book closing*):

- **Export / import folder**: where the export files go, for example a
  folder synced to your PC or notes vault. Export is off until a folder is set.
- **Export characters on book closing**: writes the export file on every
  settings save (book close and KOReader's periodic autosave).
- **Export characters now**: writes it immediately. Also available as the
  gesture / profile action *Character Tracker: export characters*.
- **Keep all characters on import** (on by default): characters missing from
  an imported file stay on the device. Turn it off to let deletions made in the
  file remove characters that were not changed after the file was written.

The export file is `<folder>/<book file name>.characters.json`
(`<series_name>.series.characters.json` in series mode), pretty-printed with
sorted keys so it diffs well in git:

```json
{
    "characters": [
        {
            "aliases": ["Wenjie"],
            "created": "2026-11-24 09:19",
            "name": "Ye Wenjie",
            "notes": [],
            "rating": 0,
            "relationships": [],
            "role": "main",
            "updated": "2026-11-24 09:50:00"
        }
    ],
    "datetime": "2026-11-24 09:47:12",
    "device_id": "0123456789ABCDEF0123456789ABCDEF"
}
```

**Import:** when the export file was written by another device (a different
`device_id`), the characters are merged: for a character present on both
sides the newer one wins (the later of its `updated` and `created` stamps),
characters only in the file are added. The merged list is saved and the
export file is rewritten as this device's copy. This happens when the book is
opened, and also while it stays open: on wake-up and, at most every 30
seconds, on page turns, the plugin checks whether the file changed (e.g. a
sync client brought a new version).

**No idle rewrites:** the export file is only rewritten when the characters
changed, not on every save, so a synced folder (git, Syncthing…) does not see
a new version each time the device goes to sleep. If the file holds changes
from elsewhere that were not merged yet, they are merged before writing, never
overwritten.

**Editing the file by hand** (e.g. on your PC), the same way as KOReader's
annotation export files:

1. Change any character of `device_id`, so the device treats the file as
   coming from elsewhere.
2. On every character you change or add, set `"updated"` to the current time
   (`YYYY-MM-DD HH:MM:SS`), newer than the device's copy.
3. If the device changes the same character before your edit arrives, the
   newer change wins; with a git-synced folder, both sides changing the file
   at the same time is a merge conflict to resolve in git.

The plugin sets `updated` by itself whenever a character changes on the device.

---

## Translations

The plugin follows KOReader's UI language. Available: **Turkish** (`tr`).

Its strings are not part of KOReader's own translations, so they live in
standard gettext PO files in `l10n/`. To add a language, copy `l10n/tr.po`
to `l10n/<code>.po`, where `<code>` is KOReader's language code (`de`,
`pt_BR`, ...), translate the `msgstr` lines and restart KOReader. No code
change is needed. A regional code falls back to the base language
(`pt_BR` → `pt.po`), and a string missing from the PO falls back to
KOReader's own translation, then to English.

---

## File structure

```
charactertracker.koplugin/
├── _meta.lua    # Plugin metadata
├── main.lua     # Plugin logic
├── l10n.lua     # Loads the translations below
└── l10n/
    └── tr.po    # Turkish
```


---

Suggestions welcome — open an issue.

---

## License

GNU AGPL v3 — same as KOReader.
