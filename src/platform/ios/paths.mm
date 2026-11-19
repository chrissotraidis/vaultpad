#include "paths.h"

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

#include <SDL.h>
#include <SDL_syswm.h>

// Modelled after SDL_AndroidGetExternalStoragePath.
const char* iOSGetDocumentsPath()
{
    static char* s_iOSDocumentsPath = nullptr;

    if (s_iOSDocumentsPath == nullptr) {
        @autoreleasepool {
            NSArray* array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

            if ([array count] > 0) {
                NSString* str = [array objectAtIndex:0];
                const char* base = [str fileSystemRepresentation];
                if (base) {
                    const size_t len = SDL_strlen(base) + 2;
                    s_iOSDocumentsPath = (char*)SDL_malloc(len);
                    if (s_iOSDocumentsPath == nullptr) {
                        SDL_OutOfMemory();
                    } else {
                        SDL_snprintf(s_iOSDocumentsPath, len, "%s/", base);
                    }
                }
            }
        }
    }

    return s_iOSDocumentsPath;
}

bool iOSWindowIsOnExternalDisplay(SDL_Window* window)
{
    if (window == nullptr) {
        return false;
    }
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(window, &info) || info.subsystem != SDL_SYSWM_UIKIT) {
        return false;
    }
    UIScreen* screen = info.info.uikit.window.windowScene.screen;
    return screen != nil && screen != UIScreen.mainScreen;
}
