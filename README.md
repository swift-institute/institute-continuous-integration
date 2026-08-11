# institute-continuous-integration

The Institute half of continuous integration: Swift Institute policy over
the vendor-neutral CI domain and the GitHub↔CI relation.

## Products

- **Institute Continuous Integration** — the namespace shell, `Institute`
  and `Institute.ContinuousIntegration`, the owner of the relation between
  continuous-integration semantics and Institute doctrine.
- **Institute Continuous Integration Canon** — the documents this control
  plane distributes into every package (`.gitignore` canon), including
  complete-policy rendering, declared nested-package policy, and the closed
  six-capability admission vocabulary.
- **Institute Continuous Integration Validation** — the six
  Institute-policy validators (skill hygiene, gitignore canon, README
  conventions, schema correspondence, manifest binding, trust-anchor
  regeneration correspondence), registered in this
  package's own registry and conforming to the validation engine owned by
  [swift-github-continuous-integration](https://github.com/swift-foundations/swift-github-continuous-integration).
- **Institute Continuous Integration Inventory** — the structural
  inventory of the shipped CI verdict: the universal workflow's jobs,
  postures, waves, token boundary, and single aggregate — and the trust
  anchor, which pins the CI source repositories a workflow revision is
  entitled to execute and emits the generated checkout and identity
  steps that carry those pins.

The vendor-neutral continuous-integration contract lives in
[swift-continuous-integration](https://github.com/swift-foundations/swift-continuous-integration),
and the GitHub-Actions mechanics — the workflow document model, the
validation engine, and the seventeen GitHub-mechanics validators — in
[swift-github-continuous-integration](https://github.com/swift-foundations/swift-github-continuous-integration);
this package owns only what is Institute policy.

## Generated ignore policy

The generated root `.gitignore` is the complete repository policy; handwritten
tails are invalid. Declared nested packages at `Tests/Package.swift` or
`Benchmarks/Package.swift` carry the exact generated nested policy, and no
other nested `.gitignore` is admitted.

`[GH-IGNORE-004]` reads stage-0 pathnames from the real Git index with NUL-safe
transport and asks `git check-ignore --no-index` about each one. A tracked path
that remains ignored is reported by repository-relative pathname. Missing Git,
malformed index output, unreadable policy inputs, subprocess failures, and
ambient exclude policy are environment defects rather than clean verdicts.
