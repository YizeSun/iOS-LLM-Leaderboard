# Swift Code Generation Methodology

Swift code generation tasks evaluate whether a model can produce correct, maintainable code for real iOS development workflows.

## Evaluation Focus

- Swift language correctness
- SwiftUI architecture and state management
- Apple framework usage
- Compile success in a realistic project context
- XCTest coverage when requested
- Maintainability and readability

## Rubric

Use the Swift Codegen Score from [scoring.md](scoring.md):

- Compile success: 30%
- Functional correctness: 30%
- Swift idiomatic quality: 20%
- Modern Apple API usage: 10%
- Readability and architecture: 10%

## Review Expectations

Reviewers should record:

- Xcode version
- Swift version
- target platform
- warnings or compile errors
- manual fixes required, if any

Generated code should not receive full credit if it only works after substantial reviewer repair.
