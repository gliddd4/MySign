# File Directory

## Root Level
- **Documentation.md**: Project overview and documentation
- **FileDirectory.md**: This file - directory of all files and their responsibilities
- **Roadmap.md**: Planned features and enhancements
- **Accomplished.md**: Log of completed work sessions
- **Info.plist**: Application configuration
- **mysignipasigner.entitlements**: App entitlements
- **mysignipasignerApp.swift**: Main application entry point

## Managers
Location: `/Managers/`

### Core Managers
- **ThemeManager/Theme.swift**: UI theming and color management
- **ToastManager/ToastManager.swift**: Notification and toast system
- **HapticManager.swift**: Haptic feedback implementation
- **FavoritesManager.swift**: Repository favorites management
- **ValidationManager.swift**: URL and data validation
- **ESignManager.swift**: eSign code processing and encryption
- **StatusBarManager.swift**: Status bar appearance management
- **DeviceUtilities.swift**: Device information utilities

### Navigation System
- **NavigationManager/NavigationManager.swift**: Custom navigation implementation
- **NavigationManager/NavigationItem.swift**: Navigation item data structure
- **NavigationManager/PillSwitcher.swift**: Pill-style tab switcher
- **TabManager/TabManager.swift**: Tab management system
- **TabManager/TabItem.swift**: Tab item data structure
- **TabManager/TabItemView.swift**: Tab item UI component

### Wallpaper System
- **WallpaperManager/WallpaperManager.swift**: Wallpaper management
- **WallpaperManager/WallpaperView.swift**: Wallpaper display view

## Tabs
Location: `/Tabs/`

### Browse Tab
Location: `/Tabs/Browse/`

#### Repository Management
- **Toolbar/Repository Adder/AddView.swift**: Main repository manager view
- **Toolbar/Repository Adder/DeleteView.swift**: Repository deletion interface
- **Toolbar/Repository Adder/ErrorSummaryView.swift**: Processing error display
- **Toolbar/Repository Adder/ExportOptionsView.swift**: Repository export options
- **Toolbar/Repository Adder/RetryDialogView.swift**: Retry failed URLs dialog
- **Toolbar/Repository Adder/URLInputView.swift**: URL input processing
- **RepositoryCode/BrowseView.swift**: Main browse interface
- **RepositoryCode/RepositoryListView.swift**: Repository list display
- **RepositoryCode/RepositoryViewModel.swift**: Repository data management

#### Repository Icons
- **RepositoryCode/IconManager/IconManager.swift**: Icon caching and management
- **RepositoryCode/IconManager/ImageLoader.swift**: Image loading utilities
- **RepositoryCode/IconManager/RepositoryIconView.swift**: Repository icon display

#### Repository Actions
- **RepositoryMenu/RepoMenu.swift**: Repository context menu
- **RepositoryMenu/RepoMenuDelete.swift**: Delete repository action
- **RepositoryMenu/RepoMenuFavorite.swift**: Favorite repository action
- **RepositoryMenu/RepoMenuIcon.swift**: Icon management actions
- **RepositoryMenu/RepoMenuJSON.swift**: JSON export actions
- **RepositoryMenu/RepoMenuURL.swift**: URL management actions

#### App Details
- **IPA Details/IPADetailsView.swift**: App details display
- **IPA Details/DateFormatting.swift**: Date formatting utilities
- **IPA Details/FileDownloadManager.swift**: File download management
- **IPA Details/IPAActionButtons.swift**: Download/share buttons
- **IPA Details/IPADetailsSection.swift**: App details section

#### News System
- **News/NewsView.swift**: News display interface
- **News/NewsViewModel.swift**: News data management

#### Sorting
- **Toolbar/Sorting/Sorting.swift**: App and repository sorting options

### Sign Tab
Location: `/Tabs/Sign/`

#### Core Signing
- **SignView.swift**: Main signing interface
- **MetalGradientView.swift**: Gradient background view

#### Certificate Management
- **CertificateManager/CertificateManagerView.swift**: Certificate manager interface
- **CertificateManager/CertificateRowView.swift**: Certificate list item
- **CertificateManager/CertificateManager.swift**: Certificate data management
- **CertificateManager/CertificateOperations.swift**: Certificate operations

#### Tweak Management
- **TweakManager/TweakManagerView.swift**: Tweak manager interface
- **TweakManager/TweakRowView.swift**: Tweak list item
- **TweakManager/TweakOperations.swift**: Tweak operations

#### Operations
- **Operations/CirclefyOperations.swift**: Circlefy processing operations
- **Operations/IPAOperations.swift**: IPA file operations

### Downloads Tab
Location: `/Tabs/Downloads/`
- **DownloadsView.swift**: Main downloads interface
- **DownloadRowView.swift**: Download list item
- **DownloadManager.swift**: Download management system

### Files Tab
Location: `/Tabs/Files/`
- **FilesView.swift**: Main file browser interface
- **FileContentView.swift**: File content viewer
- **FileImporter.swift**: File import functionality
- **ImagePreview.swift**: Image preview display
- **SystemFileManagerModel.swift**: System file management
- **SystemFilesSection.swift**: System files section

### Settings Tab
Location: `/Tabs/Settings/`
- **SettingsView.swift**: Main settings interface
- **ThemingSettingsView.swift**: Theme customization settings
- **BrowseSettingsView.swift**: Browse tab settings
- **FilesSettingsView.swift**: Files tab settings
- **PaddingSettingsView.swift**: UI padding configuration
- **CacheSettingsView.swift**: Cache management settings
- **LogsView.swift**: Application logs display
- **WallpaperSectionView.swift**: Wallpaper settings

## UI Components
Location: `/UI/`
- **Components/BackgroundBlurView.swift**: Blurred background view
- **Components/UniversalComponents.swift**: Reusable UI components
- **ButtonStyleShowcase.swift**: Button style examples
- **MainButton.swift**: Primary button component
- **HoldAndReleaseButton.swift**: Hold-to-activate button

## Environment
Location: `/Environment/`
- **OriginalSafeAreaKey.swift**: Safe area management