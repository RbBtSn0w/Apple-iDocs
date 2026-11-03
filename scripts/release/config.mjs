// The planner and publisher consume the same version/notes policy.
export default {
  branches: ['main'],
  tagFormat: 'v${version}',
  requireBaseline: true,
  analyzer: { preset: 'conventionalcommits' },
  notes: { preset: 'conventionalcommits' },
};
