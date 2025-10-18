#import <Foundation/Foundation.h>
#import "defines.h"
#import "headers.h"
#import "operations.h"

void FixSubstrate(NSString* tweakPath) {
    NSMutableData* binary = [NSData dataWithContentsOfFile: tweakPath].mutableCopy;
    struct thin_header headers[4];
    uint32_t numHeaders = 0;
    headersFromBinary(headers, binary, &numHeaders);
    // Iterate over ever macho header
    for (uint32_t i = 0; i < numHeaders; i++) {
        struct thin_header macho = headers[i];
        NSString* newSubstratePath = @"@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate";
        // Change all Substrate paths
        // Rootfull paths
        renameBinary(binary, macho, @"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", newSubstratePath);
        renameBinary(binary, macho, @"/usr/lib/libsubstrate.dylib", newSubstratePath);
        // Rootless paths
        renameBinary(binary, macho, @"/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", newSubstratePath);
        renameBinary(binary, macho, @"/var/jb/usr/lib/libsubstrate.dylib", newSubstratePath);
    }
    [binary writeToFile: tweakPath atomically: true];
}

