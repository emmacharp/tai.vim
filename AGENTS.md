# Repository Guidelines

## Project Structure & Module Organization
- This repository hosts a single Vim plugin entrypoint: `plugin/tai.vim`. All functionality lives there, and Vim loads it automatically when the runtimepath is scanned.
- Supporting artifacts (e.g., helper scripts, documentation) are absent; any additions go alongside the existing file or under new sibling directories if functionality grows.
- Keep runtime-specific helpers (`s:` scope) near their commands so reviewers see the command definition and implementation together.

## Build, Test, and Development Commands
- No traditional build step is required. To sanity-check the plugin, run `vim -u NONE -c "source plugin/tai.vim" -c q` to ensure the script sources without errors.
- Use a `vim --clean` session to manually trigger `:Tai`, `:TaiVisual`, `:TaiBuffer`, and `:TaiFile` against sample buffers; this is the primary way to inspect behavior.
- When modifying the async helpers, spin up a test environment with `tmux` (required by the plugin) and `tai` on `PATH` to verify that queued tasks reach the tui pane as intended.

## Coding Style & Naming Conventions
- Use TABS for all indentation.
- Follow existing Vim script conventions: double-quote comments, `s:`-scoped helpers, and descriptive function names (e.g., `s:tai_handle_input`).
- Use two-space indentation for `if` bodies, while keeping continuation lines aligned with a preceding `\` for readability.
- Prefer `let l:`, `let g:`, and `let s:` prefixes for local, global, and script-scope variables respectively; this pattern is already present and eases debugging.
- Keep commands simple (e.g., `command! Tai ...`) and document their usage comments right above their definitions.

## Testing Guidelines
- There is no automated test suite. Manual verification via Vim is the norm, so describe your manual steps in PRs (commands run and buffers inspected).
- If you introduce new Vimscript helpers, include inline comments that clarify edge cases (e.g., when `tmux` is unavailable).

## Commit & Pull Request Guidelines
- Historical commits use concise, tense-neutral summaries like `Support the new Tai tui mode`. Follow this style: short, descriptive phrases without issue tracker prefixes.
- Pull requests should explain what user-visible behavior changed, note any manual verification performed, and link to issues when applicable. Include screenshots or sample prompts only if the change affects the user interface or expected output.
- Mention dependency expectations (e.g., `tai` binary and `tmux`) in PR descriptions if your changes touch those integrations.

## Configuration & Dependencies
- The plugin assumes `tai` and `tmux` are on `PATH` and that `~/.local/bin/tai` is a common install location. Document any deviation (different install paths or alternative task dispatchers) in new PRs.
- Requests are persisted under `.tai_bus/requests` and the tui pane id under `.tai_bus/tui-pane.id`; keep these directories under version control only if you deliberately check them in for test fixtures.
