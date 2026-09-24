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

- **Julia Test implementation, v1.12.6** (`julia-test-v1.12.6.jl`). Raw source:
  https://raw.githubusercontent.com/JuliaLang/julia/v1.12.6/stdlib/Test/src/Test.jl.
  Retrieved 2026-09-24, preserved unchanged, covered by the archived MIT license.
  Its `Test.Error.test_type == :nontest_error` distinguishes an exception outside
  an assertion from an assertion-contained exception. This supports treating an
  interrupted group's denominator as unknown instead of awarding misleading credit.

The archived documentation supports the test-runner design. The examiner's
2026-09-24 request defines the scoring policy: proportional credit within each
group by default, with an explicit all-or-nothing group flag. Equal check weighting,
excluding skipped/broken assertions, and retaining explicit whole-assignment gates
implement that contract; Julia's Test library does not prescribe grading policy.

No referenced implementation documents remain to be downloaded.
