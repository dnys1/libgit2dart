import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'bindings/libgit2_bindings.dart';
import 'bindings/diff.dart' as bindings;
import 'git_types.dart';
import 'oid.dart';
import 'util.dart';

class Diff {
  /// Initializes a new instance of [Diff] class from provided
  /// pointer to diff object in memory.
  ///
  /// Should be freed with `free()` to release allocated memory.
  Diff(this._diffPointer) {
    libgit2.git_libgit2_init();
  }

  Diff.parse(String content) {
    libgit2.git_libgit2_init();
    _diffPointer = bindings.parse(content);
  }

  late final Pointer<git_diff> _diffPointer;

  /// Pointer to memory address for allocated diff object.
  Pointer<git_diff> get pointer => _diffPointer;

  /// Queries how many diff records are there in a diff.
  int get length => bindings.length(_diffPointer);

  /// Returns a list of [DiffDelta]s containing file pairs with and old and new revisions.
  List<DiffDelta> get deltas {
    final length = bindings.length(_diffPointer);
    var deltas = <DiffDelta>[];
    for (var i = 0; i < length; i++) {
      deltas.add(DiffDelta(bindings.getDeltaByIndex(_diffPointer, i)));
    }
    return deltas;
  }

  /// Accumulates diff statistics for all patches.
  ///
  /// Throws a [LibGit2Error] if error occured.
  DiffStats get stats => DiffStats(bindings.stats(_diffPointer));

  /// Merges one diff into another.
  void merge(Diff diff) => bindings.merge(_diffPointer, diff.pointer);

  /// Transforms a diff marking file renames, copies, etc.
  ///
  /// This modifies a diff in place, replacing old entries that look like renames or copies
  /// with new entries reflecting those changes. This also will, if requested, break modified
  /// files into add/remove pairs if the amount of change is above a threshold.
  ///
  /// Throws a [LibGit2Error] if error occured.
  void findSimilar({
    Set<GitDiffFind> flags = const {GitDiffFind.byConfig},
    int renameThreshold = 50,
    int copyThreshold = 50,
    int renameFromRewriteThreshold = 50,
    int breakRewriteThreshold = 60,
    int renameLimit = 200,
  }) {
    final int flagsInt =
        flags.fold(0, (previousValue, e) => previousValue | e.value);

    bindings.findSimilar(
      _diffPointer,
      flagsInt,
      renameThreshold,
      copyThreshold,
      renameFromRewriteThreshold,
      breakRewriteThreshold,
      renameLimit,
    );
  }

  /// Releases memory allocated for diff object.
  void free() => bindings.free(_diffPointer);
}

class DiffDelta {
  /// Initializes a new instance of [DiffDelta] class from provided
  /// pointer to diff delta object in memory.
  DiffDelta(this._diffDeltaPointer);

  /// Pointer to memory address for allocated diff delta object.
  final Pointer<git_diff_delta> _diffDeltaPointer;

  /// Returns type of change.
  GitDelta get status {
    late final GitDelta status;
    for (var type in GitDelta.values) {
      if (_diffDeltaPointer.ref.status == type.value) {
        status = type;
      }
    }
    return status;
  }

  /// Looks up the single character abbreviation for a delta status code.
  ///
  /// When you run `git diff --name-status` it uses single letter codes in the output such as
  /// 'A' for added, 'D' for deleted, 'M' for modified, etc. This function converts a [GitDelta]
  /// value into these letters for your own purposes. [GitDelta.untracked] will return
  /// a space (i.e. ' ').
  String get statusChar => bindings.statusChar(_diffDeltaPointer.ref.status);

  /// Returns flags for the delta object.
  Set<GitDiffFlag> get flags {
    var flags = <GitDiffFlag>{};
    for (var flag in GitDiffFlag.values) {
      if (_diffDeltaPointer.ref.flags & flag.value == flag.value) {
        flags.add(flag);
      }
    }

    return flags;
  }

  /// Returns a similarity score for renamed or copied files between 0 and 100
  /// indicating how similar the old and new sides are.
  ///
  /// The similarity score is zero unless you call `find_similar()` which does
  /// a similarity analysis of files in the diff.
  int get similarity => _diffDeltaPointer.ref.similarity;

  /// Returns number of files in this delta.
  int get numberOfFiles => _diffDeltaPointer.ref.nfiles;

  /// Represents the "from" side of the diff.
  DiffFile get oldFile => DiffFile(_diffDeltaPointer.ref.old_file);

  /// Represents the "to" side of the diff.
  DiffFile get newFile => DiffFile(_diffDeltaPointer.ref.new_file);
}

/// Description of one side of a delta.
///
/// Although this is called a "file", it could represent a file, a symbolic
/// link, a submodule commit id, or even a tree (although that only if you
/// are tracking type changes or ignored/untracked directories).
class DiffFile {
  /// Initializes a new instance of [DiffFile] class from provided diff file object.
  DiffFile(this._diffFile);

  final git_diff_file _diffFile;

  /// Returns oid of the item. If the entry represents an absent side of a diff
  /// then the oid will be zeroes.
  Oid get id => Oid.fromRaw(_diffFile.id);

  /// Returns path to the entry relative to the working directory of the repository.
  String get path => _diffFile.path.cast<Utf8>().toDartString();

  /// Returns the size of the entry in bytes.
  int get size => _diffFile.size;

  /// Returns flags for the diff file object.
  Set<GitDiffFlag> get flags {
    var flags = <GitDiffFlag>{};
    for (var flag in GitDiffFlag.values) {
      if (_diffFile.flags & flag.value == flag.value) {
        flags.add(flag);
      }
    }

    return flags;
  }

  /// Returns one of the [GitFilemode] values.
  GitFilemode get mode {
    late final GitFilemode result;
    for (var mode in GitFilemode.values) {
      if (_diffFile.mode == mode.value) {
        result = mode;
      }
    }
    return result;
  }
}

class DiffStats {
  /// Initializes a new instance of [DiffStats] class from provided
  /// pointer to diff stats object in memory.
  DiffStats(this._diffStatsPointer);

  /// Pointer to memory address for allocated diff delta object.
  final Pointer<git_diff_stats> _diffStatsPointer;

  /// Returns the total number of insertions.
  int get insertions => bindings.statsInsertions(_diffStatsPointer);

  /// Returns the total number of deletions.
  int get deletions => bindings.statsDeletions(_diffStatsPointer);

  /// Returns the total number of files changed.
  int get filesChanged => bindings.statsFilesChanged(_diffStatsPointer);

  /// Print diff statistics.
  ///
  /// Width for output only affects formatting of [GitDiffStats.full].
  ///
  /// Throws a [LibGit2Error] if error occured.
  String print(Set<GitDiffStats> format, int width) {
    final int formatInt =
        format.fold(0, (previousValue, e) => previousValue | e.value);
    return bindings.statsPrint(_diffStatsPointer, formatInt, width);
  }

  /// Releases memory allocated for diff stats object.
  void free() => bindings.statsFree(_diffStatsPointer);
}
