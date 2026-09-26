extends RefCounted
## THE ORIGINAL'S MOVIES IN THE GAME (docs/cutscenes-plan.md, phase 3). The
## pack says which movie plays at which engine event (pack.json `movies`,
## SCHEMA.md section 2); the movies are the player's own, converted by the
## Faction Wars Exporter into a movies file and imported like the art set
## (src/ui/pack_import.gd, kind "movies") to user://movies/<art set>/. A
## reference whose movie is not there plays nothing, so a player without the
## movies file sees the game as it was.
##
## Played: `launch` when the Cockpit first opens in a run of the game (manual
## p022, "the introductory graphics"), `credits` from the Cockpit's View
## credits (menu.gd), `start.<side>` before a game (menu.gd), and the moments
## the simulation cues (EventBus.Cue -> UIManager).
##
## IN THE BROWSER (phase 5) the game's user:// lives in the page's memory, so
## the movies file never goes there: the browser keeps the file itself in its
## own storage (IndexedDB - on disk; WEB_JS below), and each movie is read out
## as it is about to play, into a temporary file that goes when it ends.
##
## Preloaded by path (as Movies): a new script can lag the editor's class cache.

const Player := preload("res://src/ui/movie_player.gd")

## Where movies files are imported: <root>/<art set>/movies/<nnn>.ogv.
const USER_ROOT := "user://movies"
static var UserRoot: String = USER_ROOT

## The launch movies play once per run of the game.
static var LaunchPlayed: bool = false
## No movie plays in a headless run: the test runs share the player's user://,
## and a movie holds the scene tree. The movies' own tests turn this on.
static var PlayHeadless: bool = false


## The loaded pack's movies for `event` that are there to play, in order.
static func For(event: String) -> Array[String]:
	var out: Array[String] = []
	if FactionRegistry.Pack == null or (DisplayServer.get_name() == "headless" and not PlayHeadless):
		return out
	for ref in FactionRegistry.Pack.Manifest.Movies.get(event, []):
		var path := PathOf(str(ref))
		if not path.is_empty():
			out.append(path)
	return out


static func Has(event: String) -> bool:
	return not For(event).is_empty()


## A reference's file, or "" when it is not there: "<art set>:<path>" in the
## imported movies (only an art set the pack declares), else a pack file.
static func PathOf(ref: String) -> String:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path: String
	if split[0].is_empty():
		path = "%s/%s" % [FactionRegistry.LoadedDir, ref]
	else:
		if FactionRegistry.Pack == null or not FactionRegistry.Pack.Manifest.ArtSets.has(split[0]):
			return ""
		if OS.has_feature("web"):
			WebInstall()
			var entry: Variant = WebIndex.get(split[0])
			var files: Variant = entry.get("files") if entry is Dictionary else null
			return "web:%s/%s" % [split[0], split[1]] if files is Array and (files as Array).has(split[1]) else ""
		path = "%s/%s/%s" % [UserRoot, split[0], split[1]]
	return path if FileAccess.file_exists(path) else ""


## Plays `event`'s movies over everything, then calls `done` - at once when
## there are none. Returns the player, or null. With one already playing (a
## system destroyed, then the war won that same day), these follow its own.
static func Play(tree: SceneTree, event: String, done: Callable = Callable()) -> Node:
	var paths := For(event)
	if paths.is_empty():
		if done.is_valid():
			done.call()
		return null
	var playing: Node = tree.root.get_node_or_null("MoviePlayer")
	if playing != null and not playing.is_queued_for_deletion():
		playing.Paths.append_array(paths)
		if done.is_valid():
			var before: Callable = playing.Done
			playing.Done = func() -> void:
				if before.is_valid():
					before.call()
				done.call()
		return playing
	var p := Player.new()
	p.Paths = paths
	p.Done = done
	p.Fetch = WebFetch
	tree.root.add_child(p)
	return p


## The launch movies, the first time the Cockpit opens in this run.
static func PlayLaunch(tree: SceneTree) -> Node:
	if LaunchPlayed:
		return null
	LaunchPlayed = true
	return Play(tree, "launch")


# ---- the browser (phase 5) -----------------------------------------------------

## Where a movie read out of the browser's storage plays from: the page's
## memory-only /tmp, never user:// (which the browser writes back to storage).
const WEB_TEMP := "/tmp/faction-wars-movie.ogv"

## The movies files the browser keeps: id -> {title, files: [path...],
## created_utc, exporter}. Loaded when the pack picker opens (WebInstall).
static var WebIndex: Dictionary = {}
static var _web_installed: bool = false
## Callbacks handed to the page, kept alive until the page calls them.
static var _web_keep: Array = []


## Puts fwMovies on the page and asks it what it keeps. Once; the web only.
static func WebInstall() -> void:
	if _web_installed or not OS.has_feature("web"):
		return
	_web_installed = true
	JavaScriptBridge.eval(WEB_JS, true)
	WebRefresh()


## Reads the browser's list of movies files again; `done` after.
static func WebRefresh(done: Callable = Callable()) -> void:
	if not OS.has_feature("web"):
		if done.is_valid():
			done.call()
		return
	WebInstall()
	var got := JavaScriptBridge.create_callback(func(args: Array) -> void:
		var parsed: Variant = JSON.parse_string(str(args[0])) if not args.is_empty() else null
		WebIndex = parsed if parsed is Dictionary else {}
		if done.is_valid():
			done.call())
	var failed := JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if done.is_valid():
			done.call())
	_web_keep.append_array([got, failed])
	JavaScriptBridge.get_interface("fwMovies").index().then(got, failed)


## A "web:<set>/<path>" movie, read out to WEB_TEMP: `done` gets that path,
## or "" when it cannot be read. Anything else is played where it is.
static func WebFetch(path: String, done: Callable) -> void:
	if not path.begins_with("web:"):
		done.call(path)
		return
	var rest := path.substr(4)
	var id := rest.get_slice("/", 0)
	var rel := rest.substr(id.length() + 1)
	var got := JavaScriptBridge.create_callback(func(args: Array) -> void:
		var bytes: PackedByteArray = JavaScriptBridge.js_buffer_to_packed_byte_array(args[0]) if not args.is_empty() else PackedByteArray()
		var f := FileAccess.open(WEB_TEMP, FileAccess.WRITE)
		if f == null or bytes.is_empty():
			done.call("")
			return
		f.store_buffer(bytes)
		f.close()
		done.call(WEB_TEMP))
	var failed := JavaScriptBridge.create_callback(func(_args: Array) -> void: done.call(""))
	_web_keep.append_array([got, failed])
	JavaScriptBridge.get_interface("fwMovies").read(id, rel).then(got, failed)


## A movies file gone from the browser.
static func WebRemove(id: String) -> void:
	if not OS.has_feature("web"):
		return
	WebInstall()
	WebIndex.erase(id)
	JavaScriptBridge.get_interface("fwMovies").remove(id)


## window.fwMovies: the movies file in the browser's own storage. `take`
## checks a picked file - a movies file has every entry's SHA-256 checked
## against its manifest, as the game's own import does, and the file itself is
## kept; anything else resolves null and the game imports it as before.
## `index` lists what is kept; `read` gives one entry's bytes (the exporter
## stores the movies uncompressed, so this is a slice of the file); `remove`.
const WEB_JS := r"""
window.fwMovies = window.fwMovies || (function () {
  var DB = 'faction-wars-movies', STORE = 'sets';
  function open() {
    return new Promise(function (ok, fail) {
      var r = indexedDB.open(DB, 1);
      r.onupgradeneeded = function () { r.result.createObjectStore(STORE); };
      r.onsuccess = function () { ok(r.result); };
      r.onerror = function () { fail(r.error); };
    });
  }
  function req(mode, fn) {
    return open().then(function (db) {
      return new Promise(function (ok, fail) {
        var t = db.transaction(STORE, mode), r = fn(t.objectStore(STORE));
        t.oncomplete = function () { db.close(); ok(r ? r.result : undefined); };
        t.onerror = function () { db.close(); fail(t.error); };
      });
    });
  }
  function entries(blob) {
    var tailLen = Math.min(blob.size, 65557);
    return blob.slice(blob.size - tailLen).arrayBuffer().then(function (buf) {
      var v = new DataView(buf), eocd = -1;
      for (var i = tailLen - 22; i >= 0; i--) { if (v.getUint32(i, true) === 0x06054b50) { eocd = i; break; } }
      if (eocd < 0) throw new Error('not a zip');
      var count = v.getUint16(eocd + 10, true), size = v.getUint32(eocd + 12, true), off = v.getUint32(eocd + 16, true);
      return blob.slice(off, off + size).arrayBuffer().then(function (cdb) {
        var cd = new DataView(cdb), out = {}, p = 0, dec = new TextDecoder();
        for (var n = 0; n < count; n++) {
          if (cd.getUint32(p, true) !== 0x02014b50) throw new Error('a damaged zip');
          var nlen = cd.getUint16(p + 28, true), xlen = cd.getUint16(p + 30, true), clen = cd.getUint16(p + 32, true);
          out[dec.decode(new Uint8Array(cdb, p + 46, nlen))] = { method: cd.getUint16(p + 10, true), csize: cd.getUint32(p + 20, true), lho: cd.getUint32(p + 42, true) };
          p += 46 + nlen + xlen + clen;
        }
        return out;
      });
    });
  }
  function bytesOf(blob, e) {
    return blob.slice(e.lho, e.lho + 30).arrayBuffer().then(function (hb) {
      var h = new DataView(hb), start = e.lho + 30 + h.getUint16(26, true) + h.getUint16(28, true);
      var raw = blob.slice(start, start + e.csize);
      if (e.method === 0) return raw.arrayBuffer().then(function (b) { return new Uint8Array(b); });
      if (e.method === 8) return new Response(raw.stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer().then(function (b) { return new Uint8Array(b); });
      throw new Error('an unknown compression');
    });
  }
  function hex(buf) { return Array.prototype.map.call(new Uint8Array(buf), function (b) { return ('0' + b.toString(16)).slice(-2); }).join(''); }
  return {
    take: function (blob) {
      return entries(blob).then(function (es) {
        if (!es['manifest.json']) return null;
        return bytesOf(blob, es['manifest.json']).then(function (mb) {
          var m = JSON.parse(new TextDecoder().decode(mb));
          if (m.kind !== 'movies') return null;
          var fail = function (msg) { return JSON.stringify({ ok: false, message: msg, kind: '', id: '', files: 0 }); };
          if (m.format !== 1) return fail('It is format ' + m.format + '; this version of Faction Wars reads format 1.');
          if (!/^[A-Za-z0-9_-]+$/.test(m.id || '')) return fail("Its id '" + m.id + "' is not a plain name (letters, digits, - and _).");
          var names = Object.keys(m.files || {});
          if (!names.length) return fail('Its manifest lists no files.');
          var chain = Promise.resolve(null);
          names.forEach(function (name) {
            chain = chain.then(function (bad) {
              if (bad) return bad;
              if (!es[name]) return fail('It is incomplete: ' + name + ' is listed but missing.');
              return bytesOf(blob, es[name]).then(function (b) { return crypto.subtle.digest('SHA-256', b); }).then(function (d) {
                return hex(d) === String(m.files[name]).toLowerCase() ? null : fail('It is damaged: ' + name + ' does not match its checksum.');
              });
            });
          });
          return chain.then(function (bad) {
            if (bad) return bad;
            return req('readwrite', function (s) { return s.put({ manifest: m, blob: blob, entries: es }, m.id); }).then(function () {
              if (navigator.storage && navigator.storage.persist) navigator.storage.persist();
              return JSON.stringify({ ok: true, kind: 'movies', id: m.id, files: names.length,
                message: 'Imported the movies "' + (m.title || m.id) + '" (' + names.length + ' files).' });
            });
          });
        });
      });
    },
    index: function () {
      return open().then(function (db) {
        return new Promise(function (ok, fail) {
          var out = {}, t = db.transaction(STORE, 'readonly'), c = t.objectStore(STORE).openCursor();
          c.onsuccess = function () {
            var cur = c.result;
            if (!cur) return;
            var m = cur.value.manifest;
            out[cur.key] = { title: m.title || cur.key, files: Object.keys(m.files || {}), created_utc: m.created_utc || '', exporter: m.exporter || '' };
            cur.continue();
          };
          t.oncomplete = function () { db.close(); ok(JSON.stringify(out)); };
          t.onerror = function () { db.close(); fail(t.error); };
        });
      });
    },
    read: function (id, path) {
      return req('readonly', function (s) { return s.get(id); }).then(function (v) {
        if (!v || !v.entries[path]) throw new Error('no ' + path + ' in ' + id);
        return bytesOf(v.blob, v.entries[path]);
      });
    },
    remove: function (id) { return req('readwrite', function (s) { return s.delete(id); }); }
  };
})();
"""
