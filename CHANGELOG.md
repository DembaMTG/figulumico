# Changelog

All notable changes to Figulumico are documented in this file.

The project follows Semantic Versioning.

---

## [1.0.0] - 2026-08-20

### Added

- Initial public release of Figulumico — Image to ICO Converter.
- Local PNG, JPG, JPEG, and BMP image import.
- Multiple-file import through the native file dialog.
- Drag and drop support for files and folders.
- Non-recursive folder import for supported image files.
- File queue with thumbnails, metadata, selection state, and conversion status.
- Source-image preview with transparency.
- Single-file ICO conversion.
- Batch ICO conversion.
- Multi-size ICO export with the following supported sizes:
  - 16 × 16
  - 24 × 24
  - 32 × 32
  - 48 × 48
  - 64 × 64
  - 128 × 128
  - 256 × 256
- Icon size presets:
  - Windows Standard
  - Small
  - High Resolution
  - Custom
- Image fit modes:
  - Contain
  - Center Crop
  - Stretch
- Image scaling modes:
  - Smooth
  - Pixel Perfect
- Transparent and solid-color backgrounds for unused Contain areas.
- Source-folder default output workflow using a `converted` subfolder.
- Custom output-folder selection.
- Optional output-folder selection before single-file and batch conversion.
- Existing file handling:
  - Auto Number
  - Overwrite
  - Skip
- Persistent local settings stored in `user://settings.json`.
- Settings dialog with Save and Cancel workflow.
- Batch progress display.
- Batch result dialog with success, warning, skipped, and failed result counts.
- Output-folder opening from batch results.
- Copyable batch error reports.
- About dialog with quick usage guidance.
- Contextual tooltips for important controls.
- ESC handling for dialogs and safe application exit.

### Fixed

- Fixed duplicate icon-size errors when multiple selected sizes were copied into conversion options.
- Fixed custom size selections so only the sizes currently selected in the UI are exported.
- Stabilized batch status updates and progress feedback.
- Ensured failed files do not stop remaining files in a batch conversion.
- Prevented export options from being changed while a batch conversion is running.
- Improved output-folder handling for single-file and batch conversion workflows.
- Added safe fallback behavior for missing or invalid settings files.

### Changed

- The collision strategy `Ask` is not exposed in the v1.0.0 user interface.
- Auto Number remains the default collision strategy to prevent unintentional overwrites.

### Privacy

- All image processing runs locally on the user's device.
- No cloud upload, telemetry, user account, or remote image-processing service is required.

### Known Limitations

- v1.0.0 is released for Windows x64 only.
- Folder import does not scan subfolders.
- SVG import is not included.
- WebP import is not included.
- Background removal is not included.
- Conversion history is not included.
- ICO inspection tools are not included.
