# mysignipasigner Documentation

## Overview

The **mysignipasigner** is an iOS application designed for IPA signing, repository management, and file operations. It provides a comprehensive toolkit for iOS developers and enthusiasts to manage, sign, and install IPA files with custom certificates and provisioning profiles.

## Core Features

### 1. Repository Management
- Browse and manage multiple IPA repositories
- Add repositories via URLs or eSign codes
- Delete repositories in bulk
- Export repository lists in various formats
- Repository favorites system

### 2. IPA Signing & Installation
- Sign IPA files using custom certificates and provisioning profiles
- Install signed IPAs directly to device
- Tweak management for customizing apps
- Certificate management system

### 3. File Operations
- Built-in file browser with system file access
- Image preview capabilities
- File import/export functionality
- Unified document picker

### 4. Downloads Management
- Track and manage IPA downloads
- View download progress and history
- Resume failed downloads

### 5. Customization
- Theme customization with accent colors
- Wallpaper support
- UI padding and layout controls
- Dock and tab management

## UX Pathways

### Repository Management Flow
1. User navigates to Browse tab
2. Clicks "Add" to open Repository Manager
3. Inputs repository URLs or eSign codes
4. Processes and validates repositories
5. Manages existing repositories through delete/export options

### IPA Signing Flow
1. User navigates to Sign tab
2. Selects IPA file for signing
3. Chooses certificate and provisioning profile
4. Applies optional tweaks or modifications
5. Signs and optionally installs the IPA

### File Browsing Flow
1. User accesses file browser through Files tab
2. Navigates through file system directories
3. Views file content or metadata
4. Performs file operations (import/export, preview)

## High-Level Architecture

### Tab-Based Navigation
The application is organized into several main tabs:
- **Browse**: Repository management and IPA browsing
- **Sign**: IPA signing and certificate management
- **Downloads**: Download management and history
- **Files**: File system browser and operations
- **Settings**: Application configuration and customization

### MVVM Architecture
The codebase follows the Model-View-ViewModel (MVVM) pattern with:
- **Models**: Data structures (RepositoryFormat, App, Certificate, etc.)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Observable objects managing business logic

### Core Managers
Several singleton managers handle specific functionality:
- **RepositoryViewModel**: Repository data management
- **DownloadManager**: Download operations tracking
- **IconManager**: App icon caching and management
- **Theme**: UI theming and customization
- **ToastManager**: User notifications and alerts
- **HapticManager**: Haptic feedback

## Key Components

### Repository System
- Repository fetching and caching
- App data parsing and organization
- Icon loading and tint color extraction

### Signing Engine
- Integration with ArkSigning backend
- Certificate and provisioning profile management
- IPA file processing and modification

### UI Components
- Custom navigation system with pill switchers
- Tab management with dock support
- Toast notifications with animations
- Context menus for various actions

## Technical Considerations

### iOS Compatibility
- Supports iOS 15+ devices
- Uses modern SwiftUI patterns
- Implements iOS-native UI components

### Performance Optimization
- Asynchronous data loading
- Image caching and lazy loading
- Background processing for heavy operations
- Memory management for large file operations

### Security
- Secure handling of certificates and provisioning profiles
- Encrypted eSign code processing
- File system access within iOS sandbox constraints

## Third-Party Integrations
- **ArkSigning**: Core IPA signing engine
- **Nuke**: Image loading framework
- **ZIP Foundation**: Archive handling

## Development Guidelines
- Follow iOS 15+ SwiftUI patterns
- Use NavigationView instead of NavigationStack
- Implement proper haptic feedback
- Add toast notifications for user actions
- Maintain consistent UI theming