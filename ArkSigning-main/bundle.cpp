#include "bundle.h"
#include "macho.h"
#include "sys/stat.h"
#include "sys/types.h"
#include "common/base64.h"
#include "common/common.h"

ZAppBundle::ZAppBundle()
{
    m_pSignAsset = NULL;
    m_bForceSign = false;
    m_bWeakInject = false;
}

bool ZAppBundle::GetAppIcon(const string& appFolder, string& iconBase64) {
    string strInfoPlistPath = appFolder + "/Info.plist";
    string strInfoPlistData;
    ReadFile(strInfoPlistPath.c_str(), strInfoPlistData);
    
    JValue jvInfo;
    jvInfo.readPList(strInfoPlistData);
    
    vector<string> possibleIconPaths;
    
    if (jvInfo.has("CFBundleIcons")) {
        JValue iconDict = jvInfo["CFBundleIcons"];
        if (iconDict.has("CFBundlePrimaryIcon") && iconDict["CFBundlePrimaryIcon"].has("CFBundleIconFiles")) {
            JValue iconFiles = iconDict["CFBundlePrimaryIcon"]["CFBundleIconFiles"];
            for (int i = 0; i < iconFiles.size(); i++) {
                string iconName = iconFiles[i].asString();
                possibleIconPaths.push_back(appFolder + "/" + iconName + ".png");
                possibleIconPaths.push_back(appFolder + "/" + iconName + "@2x.png");
                possibleIconPaths.push_back(appFolder + "/" + iconName + "@3x.png");
            }
        }
    }
    
    if (jvInfo.has("CFBundleIconFiles")) {
        JValue iconFiles = jvInfo["CFBundleIconFiles"];
        for (int i = 0; i < iconFiles.size(); i++) {
            string iconName = iconFiles[i].asString();
            possibleIconPaths.push_back(appFolder + "/" + iconName);
            possibleIconPaths.push_back(appFolder + "/" + iconName + ".png");
        }
    }
    
    if (jvInfo.has("CFBundleIconFile")) {
        string iconName = jvInfo["CFBundleIconFile"].asString();
        possibleIconPaths.push_back(appFolder + "/" + iconName);
        possibleIconPaths.push_back(appFolder + "/" + iconName + ".png");
    }
    
    possibleIconPaths.push_back(appFolder + "/AppIcon.png");
    possibleIconPaths.push_back(appFolder + "/Icon.png");
    possibleIconPaths.push_back(appFolder + "/Icon@2x.png");
    
    DIR* dir = opendir((appFolder + "/Assets.xcassets").c_str());
    if (dir != NULL) {
        dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            string name = entry->d_name;
            if (name.find("AppIcon") != string::npos && entry->d_type == DT_DIR) {
                string iconsetPath = appFolder + "/Assets.xcassets/" + name;
                
                DIR* iconsetDir = opendir(iconsetPath.c_str());
                if (iconsetDir != NULL) {
                    dirent* iconFile;
                    while ((iconFile = readdir(iconsetDir)) != NULL) {
                        string iconName = iconFile->d_name;
                        if (iconName.find(".png") != string::npos) {
                            possibleIconPaths.push_back(iconsetPath + "/" + iconName);
                        }
                    }
                    closedir(iconsetDir);
                }
            }
        }
        closedir(dir);
    }
    
    for (const string& iconPath : possibleIconPaths) {
        if (IsFileExists(iconPath.c_str())) {
            string iconData;
            if (ReadFile(iconPath.c_str(), iconData)) {
                ZBase64 b64;
                iconBase64 = b64.Encode(iconData.c_str(), iconData.size());
                return true;
            }
        }
    }
    
    return false;
}

bool ZAppBundle::GetAppInfoJson(JValue& jvInfo) {
    if (!FindAppFolder(m_strAppFolder, m_strAppFolder)) {
        ZLog::ErrorV(">>> Can't Find App Folder! %s\n", m_strAppFolder.c_str());
        return false;
    }

    jvInfo["path"] = m_strAppFolder;
    
    if (!GetSignFolderInfo(m_strAppFolder, jvInfo, true)) {
        ZLog::ErrorV(">>> Can't Get App Info from Info.plist! %s\n", m_strAppFolder.c_str());
        return false;
    }

    JValue jvComponents;
    CollectAppInfo(m_strAppFolder, jvComponents);
    if (!jvComponents.isNull()) {
        jvInfo["components"] = jvComponents;
    }

    string provPath = m_strAppFolder + "/embedded.mobileprovision";
    jvInfo["has_provisioning_profile"] = IsFileExists(provPath.c_str());

    string iconBase64;
    if (GetAppIcon(m_strAppFolder, iconBase64)) {
        jvInfo["icon_base64"] = iconBase64;
    }

    return true;
}


void ZAppBundle::CollectAppInfo(const string& strFolder, JValue& jvInfo) {
    DIR* dir = opendir(strFolder.c_str());
    if (NULL != dir) {
        dirent* ptr = readdir(dir);
        while (NULL != ptr) {
            if (0 != strcmp(ptr->d_name, ".") && 0 != strcmp(ptr->d_name, "..")) {
                if (DT_DIR == ptr->d_type) {
                    string strSubFolder = strFolder + "/" + ptr->d_name;
                    
                    // Check if it's a framework, plugin, or app extension
                    if (IsPathSuffix(strSubFolder, ".framework") ||
                        IsPathSuffix(strSubFolder, ".appex") ||
                        IsPathSuffix(strSubFolder, ".app")) {
                            
                        JValue jvComponent;
                        if (GetSignFolderInfo(strSubFolder, jvComponent, true)) {
                            string type = "unknown";
                            if (IsPathSuffix(strSubFolder, ".framework")) {
                                type = "framework";
                            } else if (IsPathSuffix(strSubFolder, ".appex")) {
                                type = "extension";
                            } else if (IsPathSuffix(strSubFolder, ".app")) {
                                type = "application";
                            }
                            jvComponent["type"] = type;
                            jvInfo.push_back(jvComponent);
                        }
                    }
                    CollectAppInfo(strSubFolder, jvInfo);
                }
            }
            ptr = readdir(dir);
        }
        closedir(dir);
    }
}

// Global function for use in other files
bool FindAppFolder(const string &strFolder, string &strAppFolder) {
  if (IsPathSuffix(strFolder, ".app") || IsPathSuffix(strFolder, ".appex")) {
    strAppFolder = strFolder;
    return true;
  }

  DIR *dir = opendir(strFolder.c_str());
  if (NULL != dir) {
    dirent *ptr = readdir(dir);
    while (NULL != ptr) {
      if (0 != strcmp(ptr->d_name, ".") && 0 != strcmp(ptr->d_name, "..") &&
          0 != strcmp(ptr->d_name, "__MACOSX")) {
        bool isdir = false;
        if (DT_DIR == ptr->d_type) {
          isdir = true;
        } else if (DT_UNKNOWN == ptr->d_type) {
          // Entry type can be unknown depending on the underlying file system
          ZLog::DebugV(">>> Unknown directory entry type for %s, falling back "
                       "to POSIX-compatible check\n",
                       strFolder.c_str());
          struct stat statbuf;
          stat(strFolder.c_str(), &statbuf);
          if (S_ISDIR(statbuf.st_mode)) {
            isdir = true;
          }
        }
        if (isdir) {
          string strSubFolder = strFolder;
          strSubFolder += "/";
          strSubFolder += ptr->d_name;
          if (FindAppFolder(strSubFolder, strAppFolder)) {
            return true;
          }
        }
      }
      ptr = readdir(dir);
    }
    closedir(dir);
  }
  return false;
}

// Class method delegates to the global function
bool ZAppBundle::FindAppFolder(const string &strFolder, string &strAppFolder) {
  return ::FindAppFolder(strFolder, strAppFolder);
}

bool ZAppBundle::GetSignFolderInfo(const string &strFolder, JValue &jvNode,
                                   bool bGetName) {
  JValue jvInfo;
  string strInfoPlistData;
  string strInfoPlistPath = strFolder + "/Info.plist";
  ReadFile(strInfoPlistPath.c_str(), strInfoPlistData);
  jvInfo.readPList(strInfoPlistData);
  string strBundleId = jvInfo["CFBundleIdentifier"];
  string strBundleExe = jvInfo["CFBundleExecutable"];
  string strBundleVersion = jvInfo["CFBundleVersion"];
  if (strBundleId.empty() || strBundleExe.empty()) {
    return false;
  }

  string strInfoPlistSHA1Base64;
  string strInfoPlistSHA256Base64;
  SHASumBase64(strInfoPlistData, strInfoPlistSHA1Base64,
               strInfoPlistSHA256Base64);

  jvNode["bundle_id"] = strBundleId;
  jvNode["bundle_version"] = strBundleVersion;
  jvNode["exec_name"] = strBundleExe;
  jvNode["sha1"] = strInfoPlistSHA1Base64;
  jvNode["sha2"] = strInfoPlistSHA256Base64;

  if (bGetName) {
    string strBundleName = jvInfo["CFBundleDisplayName"];
    if (strBundleName.empty()) {
      strBundleName = jvInfo["CFBundleName"].asCString();
    }
    jvNode["appname"] = strBundleName;
  }

  return true;
}

bool ZAppBundle::GetObjectsToSign(const string &strFolder, JValue &jvInfo) {
  DIR *dir = opendir(strFolder.c_str());
  if (NULL != dir) {
    dirent *ptr = readdir(dir);
    while (NULL != ptr) {
      if (0 != strcmp(ptr->d_name, ".") && 0 != strcmp(ptr->d_name, "..")) {
        string strNode = strFolder + "/" + ptr->d_name;
        if (DT_DIR == ptr->d_type) {
          if (IsPathSuffix(strNode, ".app") ||
              IsPathSuffix(strNode, ".appex") ||
              IsPathSuffix(strNode, ".framework") ||
              IsPathSuffix(strNode, ".xctest")) {
            JValue jvNode;
            jvNode["path"] = strNode.substr(m_strAppFolder.size() + 1);
            if (GetSignFolderInfo(strNode, jvNode)) {
              if (GetObjectsToSign(strNode, jvNode)) {
                jvInfo["folders"].push_back(jvNode);
              }
            }
          } else {
            GetObjectsToSign(strNode, jvInfo);
          }
        } else if (DT_REG == ptr->d_type) {
          if (IsPathSuffix(strNode, ".dylib")) {
            jvInfo["files"].push_back(
                strNode.substr(m_strAppFolder.size() + 1));
          }
        }
      }
      ptr = readdir(dir);
    }
    closedir(dir);
  }
  return true;
}

bool RemoveEmbeddedMobileProvision(const string &appFolder) {
    string provisionPath = appFolder + "/embedded.mobileprovision";
    if (IsFileExists(provisionPath.c_str())) {
        if (remove(provisionPath.c_str()) != 0) {
            ZLog::ErrorV(">>> Failed to remove embedded.mobileprovision: %s\n", strerror(errno));
            return false;
        }
        ZLog::PrintV(">>> Removed embedded.mobileprovision\n");
    }
    return true;
}

void ZAppBundle::GetFolderFiles(const string &strFolder,
                                const string &strBaseFolder,
                                set<string> &setFiles) {
  DIR *dir = opendir(strFolder.c_str());
  if (NULL != dir) {
    dirent *ptr = readdir(dir);
    while (NULL != ptr) {
      if (0 != strcmp(ptr->d_name, ".") && 0 != strcmp(ptr->d_name, "..")) {
        string strNode = strFolder;
        strNode += "/";
        strNode += ptr->d_name;
        if (DT_DIR == ptr->d_type) {
          GetFolderFiles(strNode, strBaseFolder, setFiles);
        } else if (DT_REG == ptr->d_type) {
          setFiles.insert(strNode.substr(strBaseFolder.size() + 1));
        }
      }
      ptr = readdir(dir);
    }
    closedir(dir);
  }
}

bool ZAppBundle::GenerateCodeResources(const string &strFolder,
                                       JValue &jvCodeRes) {
  jvCodeRes.clear();

  set<string> setFiles;
  GetFolderFiles(strFolder, strFolder, setFiles);

  JValue jvInfo;
  string strInfoPlistPath = strFolder + "/Info.plist";
  jvInfo.readPListFile(strInfoPlistPath.c_str());
  string strBundleExe = jvInfo["CFBundleExecutable"];
  setFiles.erase(strBundleExe);
  setFiles.erase("_CodeSignature/CodeResources");

  jvCodeRes["files"] = JValue(JValue::E_OBJECT);
  jvCodeRes["files2"] = JValue(JValue::E_OBJECT);

  for (set<string>::iterator it = setFiles.begin(); it != setFiles.end();
       it++) {
    string strKey = *it;
    string strFile = strFolder + "/" + strKey;
    string strFileSHA1Base64;
    string strFileSHA256Base64;
    SHASumBase64File(strFile.c_str(), strFileSHA1Base64, strFileSHA256Base64);

    bool bomit1 = false;
    bool bomit2 = false;

    if ("Info.plist" == strKey || "PkgInfo" == strKey) {
      bomit2 = true;
    }

    if (IsPathSuffix(strKey, ".DS_Store")) {
      bomit2 = true;
    }

    if (IsPathSuffix(strKey, ".lproj/locversion.plist")) {
      bomit1 = true;
      bomit2 = true;
    }

    if (!bomit1) {
      if (string::npos != strKey.rfind(".lproj/")) {
        jvCodeRes["files"][strKey]["hash"] = "data:" + strFileSHA1Base64;
        jvCodeRes["files"][strKey]["optional"] = true;
      } else {
        jvCodeRes["files"][strKey] = "data:" + strFileSHA1Base64;
      }
    }

    if (!bomit2) {
      jvCodeRes["files2"][strKey]["hash"] = "data:" + strFileSHA1Base64;
      jvCodeRes["files2"][strKey]["hash2"] = "data:" + strFileSHA256Base64;
      if (string::npos != strKey.rfind(".lproj/")) {
        jvCodeRes["files2"][strKey]["optional"] = true;
      }
    }
  }

  jvCodeRes["rules"]["^.*"] = true;
  jvCodeRes["rules"]["^.*\\.lproj/"]["optional"] = true;
  jvCodeRes["rules"]["^.*\\.lproj/"]["weight"] = 1000.0;
  jvCodeRes["rules"]["^.*\\.lproj/locversion.plist$"]["omit"] = true;
  jvCodeRes["rules"]["^.*\\.lproj/locversion.plist$"]["weight"] = 1100.0;
  jvCodeRes["rules"]["^Base\\.lproj/"]["weight"] = 1010.0;
  jvCodeRes["rules"]["^version.plist$"] = true;

  jvCodeRes["rules2"]["^.*"] = true;
  jvCodeRes["rules2"][".*\\.dSYM($|/)"]["weight"] = 11.0;
  jvCodeRes["rules2"]["^(.*/)?\\.DS_Store$"]["omit"] = true;
  jvCodeRes["rules2"]["^(.*/)?\\.DS_Store$"]["weight"] = 2000.0;
  jvCodeRes["rules2"]["^.*\\.lproj/"]["optional"] = true;
  jvCodeRes["rules2"]["^.*\\.lproj/"]["weight"] = 1000.0;
  jvCodeRes["rules2"]["^.*\\.lproj/locversion.plist$"]["omit"] = true;
  jvCodeRes["rules2"]["^.*\\.lproj/locversion.plist$"]["weight"] = 1100.0;
  jvCodeRes["rules2"]["^Base\\.lproj/"]["weight"] = 1010.0;
  jvCodeRes["rules2"]["^Info\\.plist$"]["omit"] = true;
  jvCodeRes["rules2"]["^Info\\.plist$"]["weight"] = 20.0;
  jvCodeRes["rules2"]["^PkgInfo$"]["omit"] = true;
  jvCodeRes["rules2"]["^PkgInfo$"]["weight"] = 20.0;
  jvCodeRes["rules2"]["^embedded\\.provisionprofile$"]["weight"] = 20.0;
  jvCodeRes["rules2"]["^version\\.plist$"]["weight"] = 20.0;

  return true;
}

void ZAppBundle::GetChangedFiles(JValue &jvNode,
                                 vector<string> &arrChangedFiles) {
  if (jvNode.has("files")) {
    for (size_t i = 0; i < jvNode["files"].size(); i++) {
      arrChangedFiles.push_back(jvNode["files"][i]);
    }
  }

  if (jvNode.has("folders")) {
    for (size_t i = 0; i < jvNode["folders"].size(); i++) {
      JValue &jvSubNode = jvNode["folders"][i];
      GetChangedFiles(jvSubNode, arrChangedFiles);
      string strPath = jvSubNode["path"];
      arrChangedFiles.push_back(strPath + "/_CodeSignature/CodeResources");
      arrChangedFiles.push_back(strPath + "/" + jvSubNode["exec"].asString());
    }
  }
}

void ZAppBundle::GetNodeChangedFiles(JValue &jvNode, bool dontGenerateEmbeddedMobileProvision)
{
    if (jvNode.has("folders"))
    {
        for (size_t i = 0; i < jvNode["folders"].size(); i++)
        {
            GetNodeChangedFiles(jvNode["folders"][i], dontGenerateEmbeddedMobileProvision);
        }
    }

    vector<string> arrChangedFiles;
    GetChangedFiles(jvNode, arrChangedFiles);
    for (size_t i = 0; i < arrChangedFiles.size(); i++)
    {
        jvNode["changed"].push_back(arrChangedFiles[i]);
    }

    if (!dontGenerateEmbeddedMobileProvision) {
        if ("/" == jvNode["path"])
        { //root
            jvNode["changed"].push_back("embedded.mobileprovision");
        }
    }
}

bool ZAppBundle::SignNode(JValue &jvNode) {
  if (jvNode.has("folders")) {
    for (size_t i = 0; i < jvNode["folders"].size(); i++) {
      if (!SignNode(jvNode["folders"][i])) {
        return false;
      }
    }
  }

  if (jvNode.has("files")) {
    for (size_t i = 0; i < jvNode["files"].size(); i++) {
      const char *szFile = jvNode["files"][i].asCString();
      ZLog::PrintV(">>> SignFile: \t%s\n", szFile);
      ZMachO macho;
      if (!macho.InitV("%s/%s", m_strAppFolder.c_str(), szFile)) {
        return false;
      }
      if (!macho.Sign(m_pSignAsset, m_bForceSign, "", "", "", "")) {
        return false;
      }
    }
  }

    ZBase64 b64;
  string strInfoPlistSHA1;
  string strInfoPlistSHA256;
  string strFolder = jvNode["path"];
  string strBundleId = jvNode["bid"];
  string strBundleExe = jvNode["exec"];
  b64.Decode(jvNode["sha1"].asCString(), strInfoPlistSHA1);
  b64.Decode(jvNode["sha2"].asCString(), strInfoPlistSHA256);
  if (strBundleId.empty() || strBundleExe.empty() || strInfoPlistSHA1.empty() ||
      strInfoPlistSHA256.empty()) {
    ZLog::ErrorV(">>> Can't Get BundleID or BundleExecute or Info.plist SHASum "
                 "in Info.plist! %s\n",
                 strFolder.c_str());
    return false;
  }

  string strBaseFolder = m_strAppFolder;
  if ("/" != strFolder) {
    strBaseFolder += "/";
    strBaseFolder += strFolder;
  }

  string strExePath = strBaseFolder + "/" + strBundleExe;
  ZLog::PrintV(">>> SignFolder: %s, (%s)\n",
               ("/" == strFolder) ? basename((char *)m_strAppFolder.c_str())
                                  : strFolder.c_str(),
               strBundleExe.c_str());

  ZMachO macho;
  if (!macho.Init(strExePath.c_str())) {
    ZLog::ErrorV(">>> Can't Parse BundleExecute File! %s\n",
                 strExePath.c_str());
    return false;
  }

  CreateFolderV("%s/_CodeSignature", strBaseFolder.c_str());
  string strCodeResFile = strBaseFolder + "/_CodeSignature/CodeResources";

  JValue jvCodeRes;
  if (!m_bForceSign) {
    jvCodeRes.readPListFile(strCodeResFile.c_str());
  }

  if (m_bForceSign || jvCodeRes.isNull()) { // create
    if (!GenerateCodeResources(strBaseFolder, jvCodeRes)) {
      ZLog::ErrorV(">>> Create CodeResources Failed! %s\n",
                   strBaseFolder.c_str());
      return false;
    }
  } else if (jvNode.has("changed")) { // use existsed
    for (size_t i = 0; i < jvNode["changed"].size(); i++) {
      string strFile = jvNode["changed"][i].asCString();
      string strRealFile = m_strAppFolder + "/" + strFile;

      string strFileSHA1Base64;
      string strFileSHA256Base64;
      if (!SHASumBase64File(strRealFile.c_str(), strFileSHA1Base64,
                            strFileSHA256Base64)) {
        ZLog::ErrorV(">>> Can't Get Changed File SHASumBase64! %s",
                     strFile.c_str());
        return false;
      }

      string strKey = strFile;
      if ("/" != strFolder) {
        strKey = strFile.substr(strFolder.size() + 1);
      }
      jvCodeRes["files"][strKey] = "data:" + strFileSHA1Base64;
      jvCodeRes["files2"][strKey]["hash"] = "data:" + strFileSHA1Base64;
      jvCodeRes["files2"][strKey]["hash2"] = "data:" + strFileSHA256Base64;

      ZLog::DebugV("\t\tChanged File: %s, %s\n", strFileSHA1Base64.c_str(),
                   strKey.c_str());
    }
  }

  string strCodeResData;
  jvCodeRes.writePList(strCodeResData);
  if (!WriteFile(strCodeResFile.c_str(), strCodeResData)) {
    ZLog::ErrorV("\tWriting CodeResources Failed! %s\n",
                 strCodeResFile.c_str());
    return false;
  }

  bool bForceSign = m_bForceSign;
  if ("/" == strFolder && !arrDyLibPaths.empty()) { // inject dylib
    for (string strDyLibPath : arrDyLibPaths) {
      macho.InjectDyLib(m_bWeakInject, strDyLibPath.c_str(), bForceSign);
    }
  }

  if (!macho.Sign(m_pSignAsset, bForceSign, strBundleId, strInfoPlistSHA1,
                  strInfoPlistSHA256, strCodeResData)) {
    return false;
  }

  return true;
}

void ZAppBundle::GetPlugIns(const string &strFolder,
                            vector<string> &arrPlugIns) {
  DIR *dir = opendir(strFolder.c_str());
  if (NULL != dir) {
    dirent *ptr = readdir(dir);
    while (NULL != ptr) {
      if (0 != strcmp(ptr->d_name, ".") && 0 != strcmp(ptr->d_name, "..")) {
        if (DT_DIR == ptr->d_type) {
          string strSubFolder = strFolder;
          strSubFolder += "/";
          strSubFolder += ptr->d_name;
          if (IsPathSuffix(strSubFolder, ".app") ||
              IsPathSuffix(strSubFolder, ".appex")) {
            arrPlugIns.push_back(strSubFolder);
          }
          GetPlugIns(strSubFolder, arrPlugIns);
        }
      }
      ptr = readdir(dir);
    }
    closedir(dir);
  }
}

bool ZAppBundle::SignFolder(arksigningAsset *pSignAsset,
                            const string &strFolder,
                            const string &strBundleID,
                            const string &strBundleVersion,
                            const string &strDisplayName,
                            const vector<string> &arrDyLibFiles,
                            bool bForce,
                            bool bWeakInject,
                            bool bEnableCache,
                            bool dontGenerateEmbeddedMobileProvision)
{
    m_bForceSign = bForce;
    m_pSignAsset = pSignAsset;
    m_bWeakInject = bWeakInject;
    if (NULL == m_pSignAsset)
    {
        return false;
    }

    if (!FindAppFolder(strFolder, m_strAppFolder))
    {
        ZLog::ErrorV(">>> Can't Find App Folder! %s\n", strFolder.c_str());
        return false;
    }


    if (dontGenerateEmbeddedMobileProvision) {
        if (!RemoveEmbeddedMobileProvision(m_strAppFolder)) {
            ZLog::ErrorV(">>> Failed to remove embedded.mobileprovision\n");
            return false;
        }
    } else {
        if (!WriteFile(pSignAsset->m_strProvisionData, "%s/embedded.mobileprovision", m_strAppFolder.c_str())) {
            ZLog::ErrorV(">>> Can't Write embedded.mobileprovision!\n");
            return false;
        }
    }

      arrDyLibPaths.clear();
    for (const auto& strDyLibFile : arrDyLibFiles)
    {
        string strDyLibData;
        ReadFile(strDyLibFile.c_str(), strDyLibData);
        if (!strDyLibData.empty())
        {
            string strFileName = basename((char *)strDyLibFile.c_str());
            if (WriteFile(strDyLibData, "%s/%s", m_strAppFolder.c_str(), strFileName.c_str()))
            {
                string dyLibPath;
                StringFormat(dyLibPath, "@executable_path/%s", strFileName.c_str());
                arrDyLibPaths.push_back(dyLibPath);
            }
        }
    }

    string strCacheName;
    SHA1Text(m_strAppFolder, strCacheName);
    if (!IsFileExistsV("./.arksigning_cache/%s.json", strCacheName.c_str()))
    {
        m_bForceSign = true;
    }

    JValue jvRoot;
    if (m_bForceSign)
    {
        jvRoot["path"] = "/";
        jvRoot["root"] = m_strAppFolder;
        if (!GetSignFolderInfo(m_strAppFolder, jvRoot, true))
        {
            ZLog::ErrorV(">>> Can't Get BundleID, BundleVersion, or BundleExecute in Info.plist! %s\n", m_strAppFolder.c_str());
            return false;
        }
        
        jvRoot["bid"] = jvRoot["bundle_id"];           // bundle_id -> bid
        jvRoot["bver"] = jvRoot["bundle_version"];     // bundle_version -> bver  
        jvRoot["exec"] = jvRoot["exec_name"];          // exec_name -> exec
        jvRoot["name"] = jvRoot["appname"];            // appname -> name
        
        if (!GetObjectsToSign(m_strAppFolder, jvRoot))
        {
            return false;
        }
        
        FixKeyMappingsRecursively(jvRoot);
        
        GetNodeChangedFiles(jvRoot, dontGenerateEmbeddedMobileProvision);
    }
    else
    {
        jvRoot.readPath("./.arksigning_cache/%s.json", strCacheName.c_str());
    }

    ZLog::PrintV(">>> Signing: \t%s ...\n", m_strAppFolder.c_str());
    ZLog::PrintV(">>> AppName: \t%s\n", jvRoot["name"].asCString());
    ZLog::PrintV(">>> BundleId: \t%s\n", jvRoot["bid"].asCString());
    ZLog::PrintV(">>> BundleVer: \t%s\n", jvRoot["bver"].asCString());
    ZLog::PrintV(">>> TeamId: \t%s\n", m_pSignAsset->m_strTeamId.c_str());
    ZLog::PrintV(">>> SubjectCN: \t%s\n", m_pSignAsset->m_strSubjectCN.c_str());
    ZLog::PrintV(">>> ReadCache: \t%s\n", m_bForceSign ? "NO" : "YES");
    ZLog::PrintV(">>> Exclude MobileProvision: \t%s\n", dontGenerateEmbeddedMobileProvision ? "YES" : "NO");

    if (SignNode(jvRoot))
    {
        if (bEnableCache)
        {
            CreateFolder("./.arksigning_cache");
            jvRoot.styleWritePath("./.arksigning_cache/%s.json", strCacheName.c_str());
        }
        return true;
    }

    return false;
}

void ZAppBundle::FixKeyMappingsRecursively(JValue& jvNode) {
    // Fix current node if it has the problematic keys
    if (jvNode.has("bundle_id") && !jvNode.has("bid")) {
        jvNode["bid"] = jvNode["bundle_id"];
    }
    if (jvNode.has("bundle_version") && !jvNode.has("bver")) {
        jvNode["bver"] = jvNode["bundle_version"];
    }
    if (jvNode.has("exec_name") && !jvNode.has("exec")) {
        jvNode["exec"] = jvNode["exec_name"];
    }
    if (jvNode.has("appname") && !jvNode.has("name")) {
        jvNode["name"] = jvNode["appname"];
    }
    
    // Recursively fix folders (frameworks, etc.)
    if (jvNode.has("folders")) {
        for (size_t i = 0; i < jvNode["folders"].size(); i++) {
            FixKeyMappingsRecursively(jvNode["folders"][i]);
        }
    }
}
