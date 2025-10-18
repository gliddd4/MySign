//
//  CertificateRowView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct CertificateRowView: View {
    let certificate: CertificateFolder
    let isDefault: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            onTap()
        }) {
            HStack {
                Image("certificate")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(certificate.teamName)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        // P12 status
                        HStack(spacing: 2) {
                            Image(systemName: certificate.p12URL != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(certificate.p12URL != nil ? .green : .red)
                            Text(".p12")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Mobile Provision status
                        HStack(spacing: 2) {
                            Image(systemName: certificate.mobileProvisionURL != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(certificate.mobileProvisionURL != nil ? .green : .red)
                            Text(".mobileprovision")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if !isDefault {
                            HStack(spacing: 2) {
                                Image(systemName: certificate.esigncertURL != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(certificate.esigncertURL != nil ? .green : .red)
                                Text(".esigncert")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}