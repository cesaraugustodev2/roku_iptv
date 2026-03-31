# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-02-03

### Added
- **Multi-Language Support**: Added localization for **English**, **Portuguese (PT-BR)**, and **Spanish (ES-ES)** using the standard `tr()` framework.
- **Remote Deep Linking**: Support for sending M3U playlist URLs remotely via cURL using Roku's External Control Protocol (ECP).
- **Metadata Visibility**: Improved the information pane to show movie covers, series descriptions, and EPG details simultaneously.

### Changed
- **UI Logic**: Refactored `MainScene.brs` to handle dynamic language switching and item focus events more efficiently.
- **Deep Link Handling**: The app now observes the global `feedurl` for real-time updates while running.

## [1.1.0] - 2026-02-03

### Added
- **Electronic Program Guide (EPG)**: Added real-time EPG fetching for live channels. Program titles and descriptions are now displayed in a dedicated details pane.
- **Advanced Series Support**: Selecting a TV series now triggers a secondary fetch to list all available seasons and episodes.
- **Premium UI/UX Overhaul**: 
    - Full 1080p modern dark-themed interface.
    - Enhanced layout with a side-by-side list and preview/info area.
    - Added a live clock and channel logo support in the details pane.
    - Automated focus handling for a smoother browsing experience.
- **Multi-Category Support**: Support for Live TV, Movies (VOD), and TV Series from Xtream Codes servers.

### Fixed
- Issue where the app would force an M3U keyboard dialog on every start even if credentials existed.
- Improved error handling for invalid IPTV server responses.

---

## [1.0.0] - Prior Versions

### Added
- Initial M3U playlist support.
- Basic SceneGraph UI with `LabelList` and `Video` nodes.
- Simple M3U parsing logic.
