# Rolecraft — Resume Builder

A standalone macOS application for turning a saved resume and a job posting into a reviewed resume, cover letter, and optional screenshot portfolio. Built with Swift, AppKit, WebKit, Vision, PDFKit, and Core Text.

The public repository includes **fictional sample resume data**. Personal resumes, application drafts, exports, settings, and credentials are not included. The portfolio assets showcase the author's projects; replace them with your own work when adapting the app.

## Features

- Classic resume layout with source editing and PDF or UTF-8 text import.
- Drag-and-drop job screenshots with local OCR and editable extracted text.
- Manual drafting, OpenAI, or a local Ollama model, selected in Settings.
- Resume and cover-letter editing, source comparison, and PDF preview.
- Qualification review before export; add factual details or acknowledge unsupported requirements.
- A manual checklist that joins wrapped posting lines, removes metadata and duplicates, and distinguishes required and preferred items. Manual items are review prompts, not assessed experience gaps.
- Automatic draft saving and migration backups that preserve existing edits and notes.
- Optional portfolio page with five projects, including Equity Orbit's home page and Physics Lab's Circle and Atoms views.
- A taller default workspace (1200 × 1144 content points), remembered window size and position, and fitting to the available display.
- Selectable-text PDFs, overflow handling, and uniquely named export folders on the Desktop.

## Build and run

Requires macOS 15 or later and Apple's Swift compiler / Command Line Tools. The build targets the Mac's native architecture; it has been tested on Apple Silicon.

```sh
git clone https://github.com/BuzzScud/RESUME-BUILDER.git
cd RESUME-BUILDER
./build.sh
```

Open `build/Rolecraft.app` in Finder. To copy it to the Desktop:

```sh
ditto build/Rolecraft.app "$HOME/Desktop/Rolecraft.app"
```

The app needs no Python, Node, terminal session, or local web server at runtime. It is ad-hoc signed for personal use. Wider distribution requires appropriate Apple signing and notarization.

## Use

1. Open Rolecraft and select the Classic sample. Use **View & edit source** to replace the fictional facts and save a personal version, or import a resume and map its contents into the Classic fields.
2. Add the employer, role, and posting. Drop screenshots, paste an image, or paste text. Review OCR text before continuing.
3. Choose a drafting mode in **Settings**, then generate.
4. Review the resume, cover letter, requirements, and comparison. Correct claims and resolve each review item.
5. Optionally include a portfolio and preview the PDF. The one-page option applies to the resume body; the portfolio is additional. Long content flows to further pages rather than being cut off.
6. Confirm the final review and export to `~/Desktop/Rolecraft Exports`. Each application gets a new folder with PDFs, editable draft JSON, and posting text.

Saved applications are accessible through **Saved drafts**. Editing the job or source facts after generation requires generating again before export.

## Drafting modes

**Manual** works without an account. It retains original wording, orders bullets/projects/skills using keyword overlap, and creates an editable cover letter from the source. It does not rewrite experience or assess whether qualifications are met. Notes are saved for review; manually edit the documents to incorporate confirmed facts.

**OpenAI** requires your own API key and a model available to your account. The initial model field is `gpt-4.1-mini` and is editable. Use **Save & test connection**. Keys are stored in macOS Keychain. Generation sends the selected resume, posting text, and confirmed additional facts to OpenAI. Requests use `store: false`; this is not a promise of zero provider retention. Provider usage may be billed.

**Ollama** requires a separately installed local Ollama service and a model that supports structured JSON. Enter the installed model name and test the connection. The default address is `http://127.0.0.1:11434`; only loopback endpoints are accepted. Model quality and Mac hardware affect results and speed.

All drafts need human review. Evidence checks reject certain unsupported additions, but do not establish the accuracy of every generated claim. Live provider generation requires configured credentials or a local model and is not part of the offline tests.

## Local data and customization

- Drafts, imported sources, and settings: `~/Library/Application Support/Rolecraft`.
- Keys: macOS Keychain, not source files or exported drafts.
- Resume seed data: `Resources/profile.json` and `Resources/library.json`.
- Portfolio descriptions/crop metadata: `Resources/portfolio.json`.
- Portfolio screenshots: `Resources/shots/`.
- Original personal PDFs and preview images are intentionally absent from the public repository; the sample uses a text preview.
- In-app source edits stay in application data. Avoid committing personal replacements for the sample resources.
- Existing manual drafts with the old checklist format are upgraded on open. The original session is backed up under the app data folder before migration.
- Screenshots are processed locally. The app does not submit applications or contact employers.

The public build uses the same app identifier and local data location as the personalized Rolecraft build. Running it on a Mac that already uses Rolecraft will expose that Mac's existing saved drafts inside the app; it does not upload them to this repository.

## Verify

After building, run the two native checks:

```sh
build/Rolecraft.app/Contents/MacOS/Rolecraft --self-test \
  "$PWD/Resources" "$PWD/build/test-output" "$PWD/tests/job-posting.png"
build/Rolecraft.app/Contents/MacOS/Rolecraft --checklist-tests \
  "$PWD/tests/checklist-cases.json"
```

These exercise draft persistence, preservation of source dates, rejection of invented skills and unknown evidence, numeric-claim fallback, loopback endpoint validation, native OCR, PDF text extraction and overflow, checklist parsing, and migration backups. Tests write only to the ignored `build/` folder.

Optional frontend syntax check (requires Node only for this development check):

```sh
node --check Resources/web/app.js
```

`tests/job-posting.png` is synthetic. The checklist cases include a public job posting that reproduced the original parsing problem. `tests/make_fixture.py` recreates the OCR fixture with Python and Pillow if needed; neither is a runtime dependency.

## Source map

| File | Responsibility |
| --- | --- |
| `Sources/main.swift` | Native window, web bridge, file dialogs, exports, and test entry points |
| `Sources/Core.swift` | Persistence, OCR, Keychain, AI adapters, evidence checks, and checklist migration |
| `Sources/PDF.swift` | Resume, portfolio, and cover-letter PDF rendering |
| `Resources/web/` | Bundled HTML, CSS, and JavaScript interface |
| `Resources/` | Sample profile, portfolio assets, and app icon |
| `build.sh` | Native compilation, resource bundling, and ad-hoc signing |

## License

This repository retains its existing GNU General Public License, version 3. See [LICENSE](LICENSE).
