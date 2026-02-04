# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-02-04

### Added
- **Main GUI Application** (MainApp.ps1)
  - Tab-based interface with 5 sections
  - One-click installation and uninstallation
  - Real-time status monitoring
  - Manual cleanup trigger
  - Settings editor
  - Protected files manager
  - Log viewer
  
- **Advanced Configuration System**
  - Customizable warning days
  - Customizable auto-deletion days
  - JSON-based configuration
  
- **Two-Stage Deletion**
  - Warning stage (configurable days)
  - Auto-deletion stage (configurable days)
  
- **File Protection System**
  - Protect files from auto-deletion
  - Manage protected files via GUI
  - JSON-based protection list
  
- **Enhanced Cleanup Dialog**
  - Checkbox-based file selection
  - Three action buttons: Delete / Skip / Protect
  - Relative path display
  - File age and size information

### Changed
- Reorganized scripts into `.system` folder
- Improved user interface with modern Windows Forms
- Enhanced logging system

## [1.0.0] - 2026-02-03

### Added
- Initial release
- Basic file cleanup functionality
- Recursive folder scanning
- Windows Task Scheduler integration
- Simple GUI for file deletion confirmation
- Logging system
