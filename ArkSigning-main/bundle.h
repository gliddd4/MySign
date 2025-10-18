#pragma once
#include "common/common.h"
#include "common/json.h"
#include "openssl.h"
#include <vector>

// Global function for finding app folders
bool FindAppFolder(const string &strFolder, string &strAppFolder);

class ZAppBundle {
public:
  ZAppBundle();

public:
    bool GetAppInfoJson(JValue& jvInfo);
    bool GetAppIcon(const string& appFolder, string& iconBase64);

  bool SignFolder(arksigningAsset *pSignAsset, const string &strFolder,
                  const string &strBundleID, const string &strBundleVersion,
                  const string &strDisplayName,
                  const vector<string> &arrDyLibFiles, bool bForce,
                  bool bWeakInject, bool bEnableCache,
                  bool dontGenerateEmbeddedMobileProvision);

private:
  bool SignNode(JValue &jvNode);
  void GetNodeChangedFiles(JValue &jvNode, bool dontGenerateEmbeddedMobileProvision);
  void GetChangedFiles(JValue &jvNode, vector<string> &arrChangedFiles);
  void GetPlugIns(const string &strFolder, vector<string> &arrPlugIns);

private:
  bool FindAppFolder(const string &strFolder, string &strAppFolder);
  bool GetObjectsToSign(const string &strFolder, JValue &jvInfo);
  bool GetSignFolderInfo(const string &strFolder, JValue &jvNode,
                         bool bGetName = false);

private:
    void CollectAppInfo(const string& strFolder, JValue& jvInfo);
  bool GenerateCodeResources(const string &strFolder, JValue &jvCodeRes);
  void GetFolderFiles(const string &strFolder, const string &strBaseFolder,
                      set<string> &setFiles);
  void FixKeyMappingsRecursively(JValue& jvNode);

private:
  bool m_bForceSign;
  bool m_bWeakInject;
  vector<string> arrDyLibPaths;
  arksigningAsset *m_pSignAsset;

public:
  string m_strAppFolder;
};
