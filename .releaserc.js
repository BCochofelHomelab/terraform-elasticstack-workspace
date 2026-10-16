// semantic-release — https://semantic-release.gitbook.io
// Runs in CI on every push to main (.github/workflows/release.yml) and
// publishes a GitHub Release + git tag. No CHANGELOG.md, no commit back.
// The same setup as homelab-proxmox-core's (docs/RELEASING.md).
//
// preset: `conventionalcommits`, matching commitlint. NOT `angular`: the
// angular parser doesn't understand the `type!:` header, so `feat!: ...`
// would produce no release at all, and a breaking change here (a renamed
// role, a removed input) must be a major.
//
// conventional-changelog-conventionalcommits is held at ^9 in package.json:
// 10.x requires conventional-changelog-writer@9, but
// @semantic-release/release-notes-generator 14.x still depends on writer
// ^8, and generateNotes fails ("Missing helper"). Move to ^10 only together
// with a release-notes-generator on writer@9.
//
// branches: main only, like the release workflow's trigger. No prerelease
// branches: they're short-lived, and a new baseline is canaried by pinning
// one workspace to the new tag, not by a prerelease.
//
// tagFormat: unprefixed (`1.0.0`), core's format. Consumers pin the exact
// tag: `?ref=1.0.0`.
module.exports = {
  branches: ['main'],
  tagFormat: '${version}',
  plugins: [
    ['@semantic-release/commit-analyzer', { preset: 'conventionalcommits' }],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
        writerOpts: {
          commitsSort: ['scope', 'subject'],
        },
      },
    ],
    '@semantic-release/github',
  ],
};
