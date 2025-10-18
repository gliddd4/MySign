//
//  ZSign.h
//  Nocturna Sideloading
//
//  Created by Jaxon Hensch on 2024-04-17.
//

#ifndef ZSign_h
#define ZSign_h

#include <stdio.h>

// ArkSigning-main wrapper function
int zsign(const char *appPath, const char *p12Path, const char *provPath, const char *pass, const char *bundleID, const char *bundleVersion, const char *displayName, const char *tweakDylib);

void registerSwiftLogCallback(void (*callback)(const char *));
void logFromCpp(const char *message);

#import "SubstrateFixer.h"

#endif /* ZSign_h */
