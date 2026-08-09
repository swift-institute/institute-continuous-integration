# institute-continuous-integration

The Institute half of continuous integration: Swift Institute policy over
the vendor-neutral CI domain and the GitHub↔CI relation.

## Products

- **Institute Continuous Integration** — the namespace shell, `Institute`
  and `Institute.ContinuousIntegration`, the owner of the relation between
  continuous-integration semantics and Institute doctrine.
- **Institute Continuous Integration Canon** — the documents this control
  plane distributes into every package (`.gitignore` canon) and how they
  are spliced: one owner for the renderer and the gate.
- **Institute Continuous Integration Validation** — the five
  Institute-policy validators (skill hygiene, gitignore canon, README
  conventions, schema correspondence, manifest binding), registered in this
  package's own registry and conforming to the validation engine owned by
  [swift-github-continuous-integration](https://github.com/swift-foundations/swift-github-continuous-integration).
- **Institute Continuous Integration Inventory** — the structural
  inventory of the shipped CI verdict: the universal workflow's jobs,
  postures, waves, token boundary, and single aggregate.

The vendor-neutral continuous-integration contract lives in
[swift-continuous-integration](https://github.com/swift-foundations/swift-continuous-integration),
and the GitHub-Actions mechanics — the workflow document model, the
validation engine, and the seventeen GitHub-mechanics validators — in
[swift-github-continuous-integration](https://github.com/swift-foundations/swift-github-continuous-integration);
this package owns only what is Institute policy.
