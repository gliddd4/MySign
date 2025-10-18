#include "bundle.h"
#include "common/common.h"
#include "signing.h"
#include <openssl/pem.h>
#include <openssl/pkcs12.h>
#include <openssl/x509.h>
#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/provider.h>
#include <openssl/err.h>

// C wrapper function to validate P12 certificate and extract team name
extern "C" int validateP12Only(const char* p12Path, const char* password,
                               char* teamNameOut, int teamNameSize) {
    
    if (!p12Path || !password || !teamNameOut || teamNameSize <= 0) {
        ZLog::ErrorV("validateP12Only: Invalid parameters\n");
        return -1; // Invalid parameters
    }
    
    // Initialize team name buffer
    memset(teamNameOut, 0, teamNameSize);
    
    ZLog::PrintV("validateP12Only: Starting validation for P12: %s\n", p12Path);
    ZLog::PrintV("validateP12Only: Password length: %d\n", (int)strlen(password));
    
    if (!IsFileExists(p12Path)) {
        ZLog::ErrorV("validateP12Only: P12 file does not exist: %s\n", p12Path);
        return -1;
    }
    
    try {
        X509 *x509Cert = NULL;
        EVP_PKEY *evpPKey = NULL;
        
        ZLog::PrintV("validateP12Only: Opening P12 file...\n");
        BIO *bioPKey = BIO_new_file(p12Path, "r");
        if (NULL == bioPKey) {
            ZLog::ErrorV("validateP12Only: Cannot open P12 file for reading\n");
            return -1; // Cannot open P12 file
        }
        
        ZLog::PrintV("validateP12Only: Loading OpenSSL providers...\n");
        OSSL_PROVIDER *legacy_provider = OSSL_PROVIDER_load(NULL, "legacy");
        OSSL_PROVIDER *default_provider = OSSL_PROVIDER_load(NULL, "default");
        
        if (!legacy_provider) {
            ZLog::ErrorV("validateP12Only: Failed to load legacy provider\n");
        }
        if (!default_provider) {
            ZLog::ErrorV("validateP12Only: Failed to load default provider\n");
        }
        
        ZLog::PrintV("validateP12Only: Parsing PKCS12 structure...\n");
        PKCS12 *p12 = d2i_PKCS12_bio(bioPKey, NULL);
        if (NULL == p12) {
            ZLog::ErrorV("validateP12Only: Invalid P12 format or corrupted file\n");
            BIO_free(bioPKey);
            // Clean up providers
            if (legacy_provider) OSSL_PROVIDER_unload(legacy_provider);
            if (default_provider) OSSL_PROVIDER_unload(default_provider);
            return -1; // Invalid P12 format
        }
        
        ZLog::PrintV("validateP12Only: Attempting to parse P12 with provided password...\n");
        if (0 == PKCS12_parse(p12, password, &evpPKey, &x509Cert, NULL)) {
            ZLog::ErrorV("validateP12Only: PKCS12_parse failed - invalid password\n");
            ERR_print_errors_fp(stderr);
            PKCS12_free(p12);
            BIO_free(bioPKey);
            // Clean up providers
            if (legacy_provider) OSSL_PROVIDER_unload(legacy_provider);
            if (default_provider) OSSL_PROVIDER_unload(default_provider);
            return -1; // Invalid password
        }
        
        ZLog::PrintV("validateP12Only: PKCS12_parse successful\n");
        PKCS12_free(p12);
        BIO_free(bioPKey);
        
        // Clean up providers after successful parsing
        if (legacy_provider) OSSL_PROVIDER_unload(legacy_provider);
        if (default_provider) OSSL_PROVIDER_unload(default_provider);
        
        if (NULL == evpPKey || NULL == x509Cert) {
            ZLog::ErrorV("validateP12Only: Failed to extract certificate or private key\n");
            if (evpPKey) EVP_PKEY_free(evpPKey);
            if (x509Cert) X509_free(x509Cert);
            return -1; // Failed to extract certificate/key
        }
        
        ZLog::PrintV("validateP12Only: Extracting subject CN...\n");
        // Extract subject CN as team name
        string teamName;
        X509_NAME *name = X509_get_subject_name(x509Cert);
        int common_name_loc = X509_NAME_get_index_by_NID(name, NID_commonName, -1);
        if (common_name_loc >= 0) {
            X509_NAME_ENTRY *common_name_entry = X509_NAME_get_entry(name, common_name_loc);
            if (common_name_entry != NULL) {
                ASN1_STRING *common_name_asn1 = X509_NAME_ENTRY_get_data(common_name_entry);
                if (common_name_asn1 != NULL) {
                    teamName.append((const char *)common_name_asn1->data, common_name_asn1->length);
                }
            }
        }
        
        if (teamName.empty()) {
            ZLog::ErrorV("validateP12Only: Could not extract team name from certificate\n");
            EVP_PKEY_free(evpPKey);
            X509_free(x509Cert);
            return -2; // No team name found
        }
        
        ZLog::PrintV("validateP12Only: Successfully extracted team name: %s\n", teamName.c_str());
        
        // Copy team name to output buffer
        size_t copyLen = min((size_t)(teamNameSize - 1), teamName.length());
        strncpy(teamNameOut, teamName.c_str(), copyLen);
        teamNameOut[copyLen] = '\0';
        
        // Clean up
        EVP_PKEY_free(evpPKey);
        X509_free(x509Cert);
        
        ZLog::PrintV("validateP12Only: Validation completed successfully\n");
        return 0; // Success
        
    } catch (const std::exception& e) {
        // Log error if needed
        ZLog::ErrorV("validateP12Only exception: %s\n", e.what());
        return -1;
    } catch (...) {
        // Catch any other exceptions
        ZLog::ErrorV("validateP12Only unknown exception\n");
        return -1;
    }
}

// C wrapper function to maintain compatibility with the existing Swift interface
extern "C" int zsign(const char* appPath, const char* p12Path, const char* provPath,
                     const char* pass, const char* bundleID, const char* bundleVersion,
                     const char* displayName, const char* tweakDylib) {
    
    ZLog::PrintV("ArkSigning wrapper called with appPath: %s\n", appPath);
    
    if (!IsFileExists(appPath)) {
        ZLog::ErrorV("Invalid Path! %s\n", appPath);
        return -1;
    }
    
    // Validate bundle information before proceeding
    if (!bundleID || strlen(bundleID) == 0) {
        ZLog::ErrorV("Bundle ID is required but not provided\n");
        return -1;
    }
    
    if (!displayName || strlen(displayName) == 0) {
        ZLog::ErrorV("Display name is required but not provided\n");
        return -1;
    }
    
    // Log the provided bundle information
    ZLog::PrintV("Bundle ID provided: %s\n", bundleID);
    ZLog::PrintV("Bundle Version provided: %s\n", bundleVersion ? bundleVersion : "not provided");
    ZLog::PrintV("Display Name provided: %s\n", displayName);
    
    // Verify that we can find and read the app's Info.plist
    string strAppFolder;
    if (!FindAppFolder(string(appPath), strAppFolder)) {
        ZLog::ErrorV("Cannot find app folder in: %s\n", appPath);
        return -1;
    }
    
    ZLog::PrintV("Found app folder: %s\n", strAppFolder.c_str());
    
    // Verify Info.plist exists and is readable
    string infoPlistPath = strAppFolder + "/Info.plist";
    if (!IsFileExists(infoPlistPath.c_str())) {
        ZLog::ErrorV("Info.plist not found at: %s\n", infoPlistPath.c_str());
        return -1;
    }
    
    // Test reading the Info.plist to ensure it's valid
    string strInfoPlistData;
    if (!ReadFile(infoPlistPath.c_str(), strInfoPlistData)) {
        ZLog::ErrorV("Cannot read Info.plist at: %s\n", infoPlistPath.c_str());
        return -1;
    }
    
    ZLog::PrintV("Successfully read Info.plist (%zu bytes)\n", strInfoPlistData.size());
    
    // Parse and validate the Info.plist
    JValue jvInfo;
    if (!jvInfo.readPList(strInfoPlistData)) {
        ZLog::ErrorV("Cannot parse Info.plist as plist format\n");
        return -1;
    }
    
    string existingBundleId = jvInfo["CFBundleIdentifier"].asString();
    string existingBundleExe = jvInfo["CFBundleExecutable"].asString();
    
    if (existingBundleId.empty() || existingBundleExe.empty()) {
        ZLog::ErrorV("Info.plist missing required keys - BundleID: '%s', BundleExecutable: '%s'\n",
                     existingBundleId.c_str(), existingBundleExe.c_str());
        return -1;
    }
    
    ZLog::PrintV("Info.plist validation successful - BundleID: %s, BundleExecutable: %s\n",
                 existingBundleId.c_str(), existingBundleExe.c_str());
    
    // Initialize the signing asset with the provided credentials
    arksigningAsset signingAsset;
    if (!signingAsset.Init("", p12Path, provPath, "", pass)) {
        ZLog::ErrorV("Failed to initialize signing asset\n");
        return -2;
    }
    
    // Create vector for dylib files
    vector<string> arrDyLibFiles;
    if (tweakDylib && strlen(tweakDylib) > 0) {
        arrDyLibFiles.push_back(string(tweakDylib));
        ZLog::PrintV("Tweak dylib provided: %s\n", tweakDylib);
    }
    
    // Convert C strings to std::string with proper validation
    string strBundleId = bundleID ? string(bundleID) : "";
    string strBundleVersion = bundleVersion ? string(bundleVersion) : "1";
    string strDisplayName = displayName ? string(displayName) : "";
    
    // Ensure we have valid bundle information
    if (strBundleId.empty()) {
        ZLog::ErrorV("Bundle ID cannot be empty\n");
        return -1;
    }
    
    if (strDisplayName.empty()) {
        ZLog::ErrorV("Display name cannot be empty\n");
        return -1;
    }
    
    ZLog::PrintV("Processed Bundle ID: %s\n", strBundleId.c_str());
    ZLog::PrintV("Processed Bundle Version: %s\n", strBundleVersion.c_str());
    ZLog::PrintV("Processed Display Name: %s\n", strDisplayName.c_str());
    
    bool needsInfoPlistUpdate = false;
    
    if (existingBundleId != strBundleId) {
        jvInfo["CFBundleIdentifier"] = strBundleId;
        needsInfoPlistUpdate = true;
        ZLog::PrintV("Updating CFBundleIdentifier: %s -> %s\n", existingBundleId.c_str(), strBundleId.c_str());
    }
    
    string existingBundleVersion = jvInfo["CFBundleVersion"].asString();
    if (existingBundleVersion != strBundleVersion) {
        jvInfo["CFBundleVersion"] = strBundleVersion;
        needsInfoPlistUpdate = true;
        ZLog::PrintV("Updating CFBundleVersion: %s -> %s\n", existingBundleVersion.c_str(), strBundleVersion.c_str());
    }
    
    // Update display name only if different
    string existingDisplayName = jvInfo.has("CFBundleDisplayName") ? jvInfo["CFBundleDisplayName"].asString() : "";
    string existingBundleName = jvInfo.has("CFBundleName") ? jvInfo["CFBundleName"].asString() : "";
    
    if (jvInfo.has("CFBundleDisplayName")) {
        if (existingDisplayName != strDisplayName) {
            jvInfo["CFBundleDisplayName"] = strDisplayName;
            needsInfoPlistUpdate = true;
            ZLog::PrintV("Updating CFBundleDisplayName: %s -> %s\n", existingDisplayName.c_str(), strDisplayName.c_str());
        }
    } else {
        if (existingBundleName != strDisplayName) {
            jvInfo["CFBundleName"] = strDisplayName;
            needsInfoPlistUpdate = true;
            ZLog::PrintV("Updating CFBundleName: %s -> %s\n", existingBundleName.c_str(), strDisplayName.c_str());
        }
    }
    
    if (needsInfoPlistUpdate) {
        string updatedInfoPlistData;
        jvInfo.writePList(updatedInfoPlistData);
        if (!WriteFile(infoPlistPath.c_str(), updatedInfoPlistData)) {
            ZLog::ErrorV("Failed to write updated Info.plist\n");
            return -1;
        }
        ZLog::PrintV("Successfully updated Info.plist with new bundle information\n");
    } else {
        ZLog::PrintV("Info.plist already has correct values, skipping update to preserve original formatting\n");
    }
    
    ZLog::PrintV("Updated Info.plist with provided bundle information\n");
    
    ZAppBundle bundle;
    
    // Initialize app folder manually
    bundle.m_strAppFolder = strAppFolder;
    
    // Sign the app bundle - disable cache and embedded mobileprovision for iOS compatibility
    bool bRet = bundle.SignFolder(&signingAsset, appPath, strBundleId,
                                  strBundleVersion, strDisplayName, arrDyLibFiles,
                                  true,  // bForce - force signing
                                  false, // bWeakInject - use strong injection
                                  false, // bEnableCache - disable cache for iOS
                                  true); // dontGenerateEmbeddedMobileProvision - don't create embedded.mobileprovision for iOS
    
    ZLog::PrintV("ArkSigning wrapper completed with result: %s\n", bRet ? "success" : "failure");
    return bRet ? 0 : -1;
}

// Swift logging callback support
static void (*swiftLogCallback)(const char *) = nullptr;

extern "C" void registerSwiftLogCallback(void (*callback)(const char *)) {
    swiftLogCallback = callback;
}

extern "C" void logFromCpp(const char *message) {
    if (swiftLogCallback) {
        swiftLogCallback(message);
    }
}
