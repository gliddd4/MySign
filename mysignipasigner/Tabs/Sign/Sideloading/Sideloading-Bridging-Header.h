// Sideloading-Bridging-Header.h
void registerSwiftLogCallback(void (*callback)(const char *));
void logFromCpp(const char *message);
// Circlefy function declaration
void ModifyExecutable(NSString* executablePath, uint32_t platform);
// Circlefy headers
#include "Circlefy/Circlefy-Bridging-Header.h"
#include "Circlefy/placeholderMachOBytes.h"
// System file access exploit
int poc(char *path);