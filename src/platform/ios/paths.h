#ifndef FALLOUT_PLATFORM_IOS_PATHS_H_
#define FALLOUT_PLATFORM_IOS_PATHS_H_

const char* iOSGetDocumentsPath();

struct SDL_Window;

// True when the window's scene is on an external display (a TV), where iPadOS
// does not grant pointer lock.
bool iOSWindowIsOnExternalDisplay(SDL_Window* window);

#endif /* FALLOUT_PLATFORM_IOS_PATHS_H_ */
