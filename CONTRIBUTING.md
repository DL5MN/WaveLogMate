# Contributing to WaveLogMate

Thanks for your interest in contributing to WaveLogMate.

## Reporting Bugs

- Use [GitHub Issues](https://github.com/dl5mn/WaveLogMate/issues).
- Include a clear title, expected behavior, actual behavior, and reproduction steps.
- Share environment details (macOS version, WSJT-X version, WaveLogMate version).
- Add logs or screenshots when useful, but never include API keys or sensitive data.

## Suggesting Features

- Open a feature request in [GitHub Issues](https://github.com/dl5mn/WaveLogMate/issues).
- Explain the problem you are trying to solve and your proposed solution.
- Include usage examples from WSJT-X and Wavelog workflows if possible.

## Pull Request Workflow

1. Fork the repository.
2. Create a branch from `main`:
   - `feat/short-description` for features
   - `fix/short-description` for bug fixes
3. Make focused, reviewable commits.
4. Run checks locally:
   - `make check` (runs format, lint, and tests)
5. Open a pull request to `main` with:
   - Problem statement
   - Summary of changes
   - Testing notes
   - Screenshots (for UI changes)

## Code Style

- Follow existing Swift conventions in the repository.
- Keep code clear and small in scope.
- Run `make format` to auto-format with `swift format` (config in `.swift-format`).
- Address lint warnings from `make lint` before submitting.
- Avoid unrelated refactors in the same pull request.

## Testing Requirements

- Add or update unit tests for behavior changes.
- Keep existing tests passing.
- Make sure `make check` passes before requesting review.

## Communication

- Be respectful, constructive, and kind.
- Assume positive intent and focus feedback on code and behavior.
- Prefer review comments with concrete suggestions.

Thanks again for helping improve WaveLogMate.
