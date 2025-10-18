//
//  FilesMenu.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct FilesMenu: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    @Binding var showRenameAlert: Bool
    @Binding var newName: String
    @Binding var showMoveSheet: Bool
    @Binding var itemToMove: FileItem?
    @Binding var showSearchPopover: Bool
    @Binding var searchDirectory: FileItem?
    
    private var isZipFile: Bool {
        item.url.pathExtension.lowercased() == "zip"
    }
    
    private var isIPAFile: Bool {
        item.url.pathExtension.lowercased() == "ipa"
    }
    
    var body: some View {
        Group {
            if isIPAFile {
                menuUnzipIPA
                Divider()
            }
            
            if item.isDirectory {
                searchMenu
                Divider()
            }
            
            menuMove
            menuShare
            
            Divider()
            
            menuRename
            
            if item.isDirectory {
                menuZip
                Divider()
                menuDelete
            } else if isZipFile {
                menuUnzip
                Divider()
                menuDelete
            } else {
                menuDelete
            }
        }
    }
    
    private var searchMenu: some View {
        Button("Search this directory") {
            searchDirectory = item
            showSearchPopover = true
            ToastManager.shared.showToast.log("Clicked Search this directory for \(item.name)")
        }
    }
    
    private var menuMove: some View {
        FilesMenuMove(
            item: item,
            viewModel: viewModel,
            showMoveSheet: $showMoveSheet,
            itemToMove: $itemToMove
        )
    }
    
    private var menuShare: some View {
        FilesMenuShare(
            item: item
        )
    }
    
    private var menuRename: some View {
        MenuRename(
            item: item,
            showRenameAlert: $showRenameAlert,
            newName: $newName
        )
    }
    
    private var menuZip: some View {
        MenuZip(
            item: item,
            viewModel: viewModel
        )
    }
    
    private var menuUnzip: some View {
        MenuUnzip(
            item: item,
            viewModel: viewModel
        )
    }
    
    private var menuUnzipIPA: some View {
        MenuUnzipIPA(
            item: item,
            viewModel: viewModel
        )
    }
    
    private var menuDelete: some View {
        FilesMenuDelete(
            item: item,
            viewModel: viewModel
        )
    }
}