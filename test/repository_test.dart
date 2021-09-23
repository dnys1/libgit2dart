import 'dart:io';

import 'package:test/test.dart';
import 'package:libgit2dart/libgit2dart.dart';
import 'helpers/util.dart';

void main() {
  group('Repository', () {
    late Repository repo;
    test('throws when repository isn\'t found at provided path', () {
      expect(
        () => Repository.open(''),
        throwsA(isA<LibGit2Error>()),
      );
    });

    group('.init()', () {
      final initDir = Directory('${Directory.systemTemp.path}/init_repo');

      setUp(() async {
        if (await initDir.exists()) {
          await initDir.delete(recursive: true);
        } else {
          await initDir.create();
        }
      });

      tearDown(() async {
        repo.free();
        await initDir.delete(recursive: true);
      });

      test('successfully creates new bare repo at provided path', () {
        repo = Repository.init(initDir.path, isBare: true);
        expect(repo.path, '${initDir.path}/');
        expect(repo.isBare, true);
      });

      test('successfully creates new standard repo at provided path', () {
        repo = Repository.init(initDir.path);
        expect(repo.path, '${initDir.path}/.git/');
        expect(repo.isBare, false);
        expect(repo.isEmpty, true);
      });
    });

    group('empty', () {
      group('bare', () {
        setUp(() {
          repo = Repository.open('test/assets/empty_bare.git');
        });

        tearDown(() {
          repo.free();
        });

        test('opens successfully', () {
          expect(repo, isA<Repository>());
        });

        test('checks if it is bare', () {
          expect(repo.isBare, true);
        });

        test('returns path to the repository', () {
          expect(
            repo.path,
            '${Directory.current.path}/test/assets/empty_bare.git/',
          );
        });

        test('returns path to root directory for the repository', () {
          expect(
            repo.commonDir,
            '${Directory.current.path}/test/assets/empty_bare.git/',
          );
        });

        test('returns empty string as path of the working directory', () {
          expect(repo.workdir, '');
        });
      });

      group('standard', () {
        setUp(() {
          repo = Repository.open('test/assets/empty_standard/.gitdir/');
        });

        tearDown(() {
          repo.free();
        });

        test('opens standart repository from working directory successfully',
            () {
          expect(repo, isA<Repository>());
        });

        test('returns path to the repository', () {
          expect(
            repo.path,
            '${Directory.current.path}/test/assets/empty_standard/.gitdir/',
          );
        });

        test('returns path to parent repo\'s .git folder for the repository',
            () {
          expect(
            repo.commonDir,
            '${Directory.current.path}/test/assets/empty_standard/.gitdir/',
          );
        });

        test('checks if it is empty', () {
          expect(repo.isEmpty, true);
        });

        test('checks if head is detached', () {
          expect(repo.isHeadDetached, false);
        });

        test('checks if branch is unborn', () {
          expect(repo.isBranchUnborn, true);
        });

        test('successfully sets identity ', () {
          repo.setIdentity(name: 'name', email: 'email@email.com');
          expect(repo.identity, {'name': 'email@email.com'});
        });

        test('successfully unsets identity', () {
          repo.setIdentity(name: null, email: null);
          expect(repo.identity, isEmpty);
        });

        test('checks if shallow clone', () {
          expect(repo.isShallow, false);
        });

        test('checks if linked work tree', () {
          expect(repo.isWorktree, false);
        });

        test('returns path to working directory', () {
          expect(
            repo.workdir,
            '${Directory.current.path}/test/assets/empty_standard/',
          );
        });
      });
    });

    group('testrepo', () {
      const lastCommit = '821ed6e80627b8769d170a293862f9fc60825226';
      const featureCommit = '5aecfa0fb97eadaac050ccb99f03c3fb65460ad4';

      late Directory tmpDir;

      setUp(() async {
        tmpDir = await setupRepo(Directory('test/assets/testrepo/'));
        repo = Repository.open(tmpDir.path);
      });

      tearDown(() async {
        repo.free();
        await tmpDir.delete(recursive: true);
      });

      test('returns config for repository', () {
        final config = repo.config;
        expect(
          config['remote.origin.url'].value,
          'git://github.com/SkinnyMind/libgit2dart.git',
        );

        config.free();
      });

      test('returns list of commits by walking from provided starting oid', () {
        const log = [
          '821ed6e80627b8769d170a293862f9fc60825226',
          '78b8bf123e3952c970ae5c1ce0a3ea1d1336f6e8',
          'c68ff54aabf660fcdd9a2838d401583fe31249e3',
          'fc38877b2552ab554752d9a77e1f48f738cca79b',
          '6cbc22e509d72758ab4c8d9f287ea846b90c448b',
          'f17d0d48eae3aa08cecf29128a35e310c97b3521',
        ];
        final commits = repo.log(lastCommit);

        for (var i = 0; i < commits.length; i++) {
          expect(commits[i].id.sha, log[i]);
        }

        for (var c in commits) {
          c.free();
        }
      });

      group('.discover()', () {
        test('discovers repository', () async {
          final subDir = '${tmpDir.path}/subdir1/subdir2/';
          await Directory(subDir).create(recursive: true);
          expect(Repository.discover(subDir), repo.path);
        });

        test('returns empty string when repository not found', () {
          expect(Repository.discover(Directory.systemTemp.path), '');
        });
      });

      test('returns empty string when there is no namespace', () {
        expect(repo.namespace, isEmpty);
      });

      test('successfully sets and unsets the namespace', () {
        expect(repo.namespace, '');
        repo.setNamespace('some');
        expect(repo.namespace, 'some');
        repo.setNamespace(null);
        expect(repo.namespace, '');
      });

      test('successfully sets working directory', () {
        final tmpWorkDir =
            Directory('${Directory.systemTemp.path}/tmp_work_dir');
        tmpWorkDir.createSync();

        repo.setWorkdir(tmpWorkDir.path);
        expect(repo.workdir, '${tmpWorkDir.path}/');

        tmpWorkDir.deleteSync();
      });

      group('setHead', () {
        late Reference head;

        setUp(() => head = repo.head);
        tearDown(() => head.free());

        test('successfully sets head when target is reference', () {
          expect(repo.head.name, 'refs/heads/master');
          expect(repo.head.target.sha, lastCommit);
          repo.setHead('refs/heads/feature');
          expect(repo.head.name, 'refs/heads/feature');
          expect(repo.head.target.sha, featureCommit);
        });

        test('successfully sets head when target is sha hex', () {
          expect(repo.head.target.sha, lastCommit);
          repo.setHead(featureCommit);
          expect(repo.head.target.sha, featureCommit);
          expect(repo.isHeadDetached, true);
        });

        test('successfully sets head when target is short sha hex', () {
          expect(repo.head.target.sha, lastCommit);
          repo.setHead(featureCommit.substring(0, 5));
          expect(repo.head.target.sha, featureCommit);
          expect(repo.isHeadDetached, true);
        });

        test('successfully attaches to an unborn branch', () {
          expect(repo.head.name, 'refs/heads/master');
          expect(repo.isBranchUnborn, false);
          repo.setHead('refs/heads/not.there');
          expect(repo.isBranchUnborn, true);
        });
      });

      group('createBlob', () {
        const newBlobContent = 'New blob\n';

        test('successfully creates new blob', () {
          final oid = repo.createBlob(newBlobContent);
          final newBlob = repo[oid.sha] as Blob;

          expect(newBlob, isA<Blob>());

          newBlob.free();
        });

        test(
            'successfully creates new blob from file at provided relative path',
            () {
          final oid = repo.createBlobFromWorkdir('feature_file');
          final newBlob = repo[oid.sha] as Blob;

          expect(newBlob, isA<Blob>());

          newBlob.free();
        });

        test('successfully creates new blob from file at provided path', () {
          final outsideFile =
              File('${Directory.current.absolute.path}/test/blob_test.dart');
          final oid = repo.createBlobFromDisk(outsideFile.path);
          final newBlob = repo[oid.sha] as Blob;

          expect(newBlob, isA<Blob>());

          newBlob.free();
        });
      });

      test('successfully creates tag with provided sha', () {
        final signature = Signature.create(
          name: 'Author',
          email: 'author@email.com',
          time: 1234,
        );
        const tagName = 'tag';
        const target = 'f17d0d48eae3aa08cecf29128a35e310c97b3521';
        const message = 'init tag\n';

        final oid = Tag.create(
          repository: repo,
          tagName: tagName,
          target: target,
          targetType: GitObject.commit,
          tagger: signature,
          message: message,
        );

        final newTag = repo[oid.sha] as Tag;
        final tagger = newTag.tagger;
        final newTagTarget = newTag.target as Commit;

        expect(newTag.id.sha, '131a5eb6b7a880b5096c550ee7351aeae7b95a42');
        expect(newTag.name, tagName);
        expect(newTag.message, message);
        expect(tagger, signature);
        expect(newTagTarget.id.sha, target);

        newTag.free();
        newTagTarget.free();
        signature.free();
      });

      test('returns status of a repository', () {
        File('${tmpDir.path}/new_file.txt').createSync();
        final index = repo.index;
        index.remove('file');
        index.add('new_file.txt');
        expect(
          repo.status,
          {
            'file': {GitStatus.indexDeleted, GitStatus.wtNew},
            'new_file.txt': {GitStatus.indexNew}
          },
        );

        index.free();
      });

      test('returns status of a single file for provided path', () {
        final index = repo.index;
        index.remove('file');
        expect(
          repo.statusFile('file'),
          {GitStatus.indexDeleted, GitStatus.wtNew},
        );
        expect(repo.statusFile('.gitignore'), {GitStatus.current});

        index.free();
      });

      test('throws when checking status of a single file for invalid path', () {
        expect(
          () => repo.statusFile('not-there'),
          throwsA(isA<LibGit2Error>()),
        );
      });

      test('returns default signature', () {
        final config = repo.config;
        config['user.name'] = 'Some Name';
        config['user.email'] = 'some@email.com';

        final signature = repo.defaultSignature;
        expect(signature.name, 'Some Name');
        expect(signature.email, 'some@email.com');

        signature.free();
        config.free();
      });
    });
  });
}
