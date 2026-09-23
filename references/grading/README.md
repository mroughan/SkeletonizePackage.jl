# Grading Implementation References

- Julia 1.12.6, Test standard-library documentation, especially "Creating Custom
  AbstractTestSet Types". Describes the supported `record`, `finish`, parent
  testset stack, and nested-type inheritance interfaces used by the behavioral
  recorder. Source: https://raw.githubusercontent.com/JuliaLang/julia/v1.12.6/stdlib/Test/docs/src/index.md
  Retrieved 2026-09-24; archived unchanged as `julia-test-v1.12.6.md`.
  Julia documentation is distributed under the Julia project's MIT license;
  see https://github.com/JuliaLang/julia/blob/v1.12.6/LICENSE.md, also archived
  unchanged as `JULIA-LICENSE.md` (retrieved 2026-09-24).
  Public rendered documentation: https://docs.julialang.org/en/v1.12/stdlib/Test/.

The archived documentation supports the test-runner design. The choice to retain
whole-run zero scoring while exposing independent test outcomes comes from the
examiner's requested grading policy, not from Julia's default scoring semantics.

No referenced implementation documents remain to be downloaded.
