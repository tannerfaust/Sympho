**Comparison Target**

- Source visual truth: `/var/folders/fq/qdy74k_56bnbmtw80nj45v7w0000gn/T/TemporaryItems/NSIRD_screencaptureui_RqTpPo/Screenshot 2026-06-18 at 16.13.03.png`
- Implementation screenshot: `/tmp/sympho-global-search-query.png`
- Combined comparison: `/tmp/sympho-search-comparison.png`
- Viewport: source normalized to 1078 × 602; implementation search surface cropped and normalized to the same size.
- State: active search query, All scope, live results, first result selected, light appearance.

**Full-view Comparison Evidence**

The implementation preserves the reference hierarchy: oversized focused search field, compact scope controls, quiet count metadata, a dominant selected result with an Enter affordance, and subordinate results below it. The implementation intentionally uses Sympho's existing semantic colors and denser macOS typography instead of copying the reference palette.

**Focused Region Comparison Evidence**

The combined comparison is focused on the complete search surface, so the input, scope chips, result icons, selection state, row rhythm, keyboard affordance, corners, and translucent surface are all readable without another crop.

**Findings**

- No actionable P0, P1, or P2 findings remain.
- Typography: system font, optical weights, truncation, and hierarchy are consistent with the existing Sympho UI and remain legible at desktop density.
- Spacing and layout: the input, scopes, results, and footer use a consistent rhythm; long result titles truncate instead of breaking the layout.
- Colors and tokens: existing Sympho semantic colors are retained as requested; glass and selection contrast remain clear over changing background content.
- Image and icon quality: the reference contains only UI icons and simple status marks. The implementation uses native SF Symbols at appropriate rendering sizes; no raster placeholders or approximate custom artwork is used.
- Copy and content: labels are concise and functional. Result subtitles expose hierarchy and state without overwhelming the title.

**Patches Made Since Initial QA Pass**

- Prevented hover-driven selection from centering and clipping the top result.
- Routed Command-F through the app command system so it works regardless of focused control or keyboard layout.
- Added tag-name matching when a tag result opens the Library.
- Verified empty results, live query updates, arrow-key movement, Enter-to-open, and Escape-to-dismiss.

**Implementation Checklist**

- [x] Search opens from the sidebar and Command-F.
- [x] Search receives focus immediately.
- [x] All, Nodes, and Tags scopes are interactive.
- [x] Results rank exact, prefix, contained, token, and subsequence matches.
- [x] Pointer and keyboard selection are supported.
- [x] Nodes, tags, domains, tracks, modules, projects, and library entries route to functional destinations.
- [x] Empty and populated states are polished.
- [x] Build and runtime launch verification pass.

**Follow-up Polish**

- P3: If a more literal Nodes density is desired later, the popup can be made wider and slightly shorter while keeping the current behavior.

final result: passed
