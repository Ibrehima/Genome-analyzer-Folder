import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genome_analyzer/models/bio_sequence.dart';
import 'package:genome_analyzer/services/app_state.dart';

/// These tests exercise [AppState]'s project CRUD / isolation logic directly
/// (without going through `loadFromDisk()`), so they only need the
/// shared_preferences mock — Hive persistence calls inside AppState use
/// null-aware operators on an uninitialized box and simply no-op, which is
/// fine for verifying in-memory state transitions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppState — project creation & defaults', () {
    test('a freshly constructed AppState defaults to the default project id', () {
      final state = AppState();
      expect(state.activeProjectId, Project.defaultId);
      expect(state.projects, isEmpty);
    });

    test('createProject adds a new project and persists it in-memory', () async {
      final state = AppState();
      final p = await state.createProject('Bacterial study', description: 'E. coli samples');
      expect(state.projects, hasLength(1));
      expect(p.name, 'Bacterial study');
      expect(p.description, 'E. coli samples');
      expect(state.projects.first.id, p.id);
    });

    test('createProject falls back to a default name when given blank input', () async {
      final state = AppState();
      final p = await state.createProject('   ');
      expect(p.name, 'Untitled project');
    });
  });

  group('AppState — active project switching', () {
    test('setActiveProject updates activeProjectId', () async {
      final state = AppState();
      final p1 = await state.createProject('Project 1');
      final p2 = await state.createProject('Project 2');
      await state.setActiveProject(p2.id);
      expect(state.activeProjectId, p2.id);
      expect(state.activeProject.id, p1.id == state.activeProjectId ? p1.id : p2.id);
      expect(state.activeProject.name, 'Project 2');
    });
  });

  group('AppState — sequence isolation between projects', () {
    test(
      'sequencesInActiveProject only returns sequences tagged with the active project',
      () async {
        final state = AppState();
        final projA = await state.createProject('Project A');
        final projB = await state.createProject('Project B');

        await state.addSequence(
          BioSequence(name: 'seqA1', type: SequenceType.dna, sequence: 'ACGT'),
          projectId: projA.id,
        );
        await state.addSequence(
          BioSequence(name: 'seqB1', type: SequenceType.dna, sequence: 'TTTT'),
          projectId: projB.id,
        );

        await state.setActiveProject(projA.id);
        expect(state.sequencesInActiveProject, hasLength(1));
        expect(state.sequencesInActiveProject.first.name, 'seqA1');

        await state.setActiveProject(projB.id);
        expect(state.sequencesInActiveProject, hasLength(1));
        expect(state.sequencesInActiveProject.first.name, 'seqB1');

        // The global (unscoped) getter must still see both.
        expect(state.sequences, hasLength(2));
      },
    );

    test('addSequences (batch) scopes every sequence to the given projectId', () async {
      final state = AppState();
      final proj = await state.createProject('Batch project');
      await state.addSequences([
        BioSequence(name: 's1', type: SequenceType.dna, sequence: 'AAAA'),
        BioSequence(name: 's2', type: SequenceType.dna, sequence: 'CCCC'),
      ], projectId: proj.id);

      await state.setActiveProject(proj.id);
      expect(state.sequencesInActiveProject, hasLength(2));
      expect(state.sequenceCountFor(proj.id), 2);
    });

    test('moveSequenceToProject re-scopes a sequence without touching others', () async {
      final state = AppState();
      final projA = await state.createProject('A');
      final projB = await state.createProject('B');
      final seq = BioSequence(name: 'movable', type: SequenceType.dna, sequence: 'GGGG');
      await state.addSequence(seq, projectId: projA.id);

      await state.moveSequenceToProject(seq.id, projB.id);

      await state.setActiveProject(projA.id);
      expect(state.sequencesInActiveProject, isEmpty);
      await state.setActiveProject(projB.id);
      expect(state.sequencesInActiveProject, hasLength(1));
      expect(state.sequencesInActiveProject.first.name, 'movable');
    });
  });

  group('AppState — project deletion', () {
    test('deleting a project cascades to delete only its own sequences', () async {
      final state = AppState();
      final projA = await state.createProject('A');
      final projB = await state.createProject('B');
      await state.addSequence(
        BioSequence(name: 'seqA', type: SequenceType.dna, sequence: 'ACGT'),
        projectId: projA.id,
      );
      await state.addSequence(
        BioSequence(name: 'seqB', type: SequenceType.dna, sequence: 'TGCA'),
        projectId: projB.id,
      );

      await state.deleteProject(projA.id);

      expect(state.projects.map((p) => p.id), isNot(contains(projA.id)));
      expect(state.sequences, hasLength(1));
      expect(state.sequences.first.name, 'seqB');
    });

    test('deleting the active project falls back to another existing project', () async {
      final state = AppState();
      final projA = await state.createProject('A');
      final projB = await state.createProject('B');
      await state.setActiveProject(projA.id);

      await state.deleteProject(projA.id);

      expect(state.activeProjectId, isNot(projA.id));
      expect(state.activeProjectId, projB.id);
    });

    test('deleteProject is a guarded no-op for the reserved default project id', () async {
      final state = AppState();
      final otherProj = await state.createProject('General');
      // Calling deleteProject with the reserved Project.defaultId constant
      // must return immediately without throwing and without touching any
      // other tracked project, even if no project currently has that id.
      await state.deleteProject(Project.defaultId);
      expect(state.projects.any((p) => p.id == otherProj.id), isTrue);
      expect(state.projects, hasLength(1));
    });
  });

  group('AppState — project renaming', () {
    test('renameProject updates name and description', () async {
      final state = AppState();
      final p = await state.createProject('Old name', description: 'old desc');
      await state.renameProject(p.id, 'New name', description: 'new desc');
      expect(state.projects.first.name, 'New name');
      expect(state.projects.first.description, 'new desc');
    });

    test('renameProject ignores a blank new name, keeping the previous one', () async {
      final state = AppState();
      final p = await state.createProject('Keep me');
      await state.renameProject(p.id, '   ');
      expect(state.projects.first.name, 'Keep me');
    });

    test('renameProject on an unknown id is a safe no-op', () async {
      final state = AppState();
      await state.createProject('Only project');
      await state.renameProject('nonexistent-id', 'Should not apply');
      expect(state.projects, hasLength(1));
      expect(state.projects.first.name, 'Only project');
    });
  });
}
