#include "quick_toolbar.h"

#if defined(__APPLE__) && TARGET_OS_IOS

#include <string.h>

#include "../../art.h"
#include "../../color.h"
#include "../../combat.h"
#include "../../display_monitor.h"
#include "../../draw.h"
#include "../../game.h"
#include "../../game_mouse.h"
#include "../../input.h"
#include "../../interface.h"
#include "../../kb.h"
#include "../../skilldex.h"
#include "../../svga.h"
#include "../../text_font.h"
#include "../../window_manager.h"

namespace fallout {

#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
extern "C" void falloutPresentIOSProductSettings();
#endif

namespace {

    enum class ToolbarAction {
        Skills,
        Cursor,
        ItemAction,
        EndTurn,
        EndCombat,
        Settings,
    };

    struct ToolbarEntry {
        ToolbarAction action;
        const char* label;
        int width;
        bool startsGroup;
    };

    // The old toolbar exposed thirteen equal-width abbreviations. Full labels
    // and progressive disclosure through the game's existing Skilldex keep the
    // same compact footprint while making every action understandable.
    constexpr ToolbarEntry kButtons[] = {
        { ToolbarAction::Skills, "Skills", 60, false },
        { ToolbarAction::Cursor, "Cursor", 64, true },
        { ToolbarAction::ItemAction, "Item Action", 82, false },
        { ToolbarAction::EndTurn, "End Turn", 72, true },
        { ToolbarAction::EndCombat, "End Combat", 88, false },
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        { ToolbarAction::Settings, "Settings", 76, true },
#endif
    };

    constexpr int kButtonCount = sizeof(kButtons) / sizeof(kButtons[0]);
    constexpr int kButtonHeight = 38;
    constexpr int kGroupGap = 6;
    constexpr int kToolbarBottomMargin = 10;
    // Window is exactly the button row — no outer padding rows, so there are no
    // pixels outside the buttons that could bleed as window background.
    constexpr int kToolbarHeight = kButtonHeight;

    int gToolbarWindow = -1;
    int gToolbarX = 0;
    int gToolbarY = 0;
    bool gShown = false;
    bool gEnabled = true;

    int visibleButtonCount()
    {
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        // Keep Settings reachable when quick actions are hidden so the choice
        // can always be reversed without editing the config by hand.
        return gEnabled ? kButtonCount : 1;
#else
        return gEnabled ? kButtonCount : 0;
#endif
    }

    int visibleEntryIndex(int visibleIndex)
    {
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        if (!gEnabled) {
            return kButtonCount - 1;
        }
#endif
        return visibleIndex;
    }

    int buttonX(int visibleIndex)
    {
        int x = 0;
        for (int i = 0; i < visibleIndex; i++) {
            int entryIndex = visibleEntryIndex(i);
            x += kButtons[entryIndex].width;
            int nextEntryIndex = visibleEntryIndex(i + 1);
            if (kButtons[nextEntryIndex].startsGroup) {
                x += kGroupGap;
            }
        }
        return x;
    }

    int toolbarWidth()
    {
        int count = visibleButtonCount();
        if (count == 0) {
            return 0;
        }

        int lastVisibleIndex = count - 1;
        int lastEntryIndex = visibleEntryIndex(lastVisibleIndex);
        return buttonX(lastVisibleIndex) + kButtons[lastEntryIndex].width;
    }

    void fillRect(unsigned char* buffer, int pitch, int x, int y, int w, int h, unsigned char color)
    {
        for (int row = 0; row < h; row++) {
            memset(buffer + (y + row) * pitch + x, color, static_cast<size_t>(w));
        }
    }

    void drawCenteredLabel(unsigned char* buffer, int pitch, int x, int y, int w, int h, const char* text, unsigned char color)
    {
        int textWidth = fontGetStringWidth(text);
        int lineHeight = fontGetLineHeight();
        int tx = x + (w - textWidth) / 2;
        // Font metrics report the full line box, but glyphs sit high within it —
        // +2 nudges the optical center down to match the panel's visual middle.
        int ty = y + (h - lineHeight) / 2 + 2;
        if (tx < x) tx = x;
        if (ty < y) ty = y;
        // Clip text to the button's right edge so a label wider than the panel
        // (e.g. localized or longer-named skill) can't overdraw adjacent buttons.
        int maxDrawWidth = x + w - tx;
        if (maxDrawWidth <= 0) {
            return;
        }
        fontDrawText(buffer + ty * pitch + tx, text, maxDrawWidth, pitch, color);
    }

    // Muted panel tuned to sit inside the same tonal range as the belt: very dim
    // fill, thin soft border, no sharp highlight/shadow. Label uses the dimmed
    // yellow of the belt's HUD text so it doesn't compete with the interface.
    void paintPanelButton(unsigned char* buffer, int pitch, int x, int y, int w, int h, const char* label, bool enabled)
    {
        unsigned char panel = intensityColorTable[COLOR_WHITE][enabled ? 8 : 5];
        unsigned char border = intensityColorTable[COLOR_WHITE][enabled ? 28 : 14];

        fillRect(buffer, pitch, x, y, w, h, panel);
        fillRect(buffer, pitch, x, y, w, 1, border);
        fillRect(buffer, pitch, x, y + h - 1, w, 1, border);
        fillRect(buffer, pitch, x, y, 1, h, border);
        fillRect(buffer, pitch, x + w - 1, y, 1, h, border);

        drawCenteredLabel(buffer, pitch, x, y, w, h, label, intensityColorTable[COLOR_LIGHT_YELLOW][enabled ? 48 : 22]);
    }

    void paintAll()
    {
        unsigned char* buffer = windowGetBuffer(gToolbarWindow);
        if (buffer == nullptr) {
            return;
        }

        int width = toolbarWidth();
        fillRect(buffer, width, 0, 0, width, kToolbarHeight, COLOR_BLACK);

        int oldFont = fontGetCurrent();
        fontSetCurrent(101);

        int buttonY = (kToolbarHeight - kButtonHeight) / 2;
        for (int visibleIndex = 0; visibleIndex < visibleButtonCount(); visibleIndex++) {
            int entryIndex = visibleEntryIndex(visibleIndex);
            const ToolbarEntry& entry = kButtons[entryIndex];
            bool enabled = entry.action != ToolbarAction::EndTurn
                && entry.action != ToolbarAction::EndCombat;
            enabled = enabled || interfaceBarEndButtonsAreEnabled();
            paintPanelButton(buffer, width, buttonX(visibleIndex), buttonY, entry.width, kButtonHeight, entry.label, enabled);
        }

        fontSetCurrent(oldFont);
    }

    // WINDOW_TRANSPARENT makes palette-0 (black) pixels composite away, so the
    // empty space around and between buttons is see-through. The button panels
    // themselves use a non-black dim gray so they still render as raised tiles.
    void createWindow()
    {
        int width = toolbarWidth();
        if (width == 0) {
            return;
        }
        gToolbarX = (screenGetWidth() - width) / 2;
        gToolbarY = screenGetHeight() - INTERFACE_BAR_HEIGHT - kToolbarHeight - kToolbarBottomMargin;

        gToolbarWindow = windowCreate(gToolbarX, gToolbarY, width, kToolbarHeight, COLOR_BLACK, WINDOW_HIDDEN | WINDOW_TRANSPARENT);
        if (gToolbarWindow == -1) {
            return;
        }

        paintAll();
    }

    void destroyWindow()
    {
        if (gToolbarWindow == -1) {
            return;
        }
        windowDestroy(gToolbarWindow);
        gToolbarWindow = -1;
    }

} // namespace

void quickToolbarInit()
{
    if (gToolbarWindow != -1 || visibleButtonCount() == 0) {
        return;
    }
    createWindow();
}

void quickToolbarFree()
{
    destroyWindow();
    gShown = false;
}

void quickToolbarShow()
{
    if (gShown || visibleButtonCount() == 0) {
        return;
    }
    if (gToolbarWindow == -1) {
        createWindow();
    }
    if (gToolbarWindow == -1) {
        return;
    }
    windowShow(gToolbarWindow);
    gShown = true;
}

void quickToolbarSetEnabled(bool enabled)
{
    if (gEnabled == enabled) {
        return;
    }
    bool wasShown = gShown;
    destroyWindow();
    gShown = false;
    gEnabled = enabled;
    if (wasShown) {
        quickToolbarShow();
    }
}

void quickToolbarHide()
{
    if (gToolbarWindow == -1 || !gShown) {
        return;
    }
    destroyWindow();
    gShown = false;
}

bool quickToolbarIsWindow(int windowId)
{
    return gToolbarWindow != -1 && windowId == gToolbarWindow;
}

bool quickToolbarContainsPoint(int x, int y)
{
    if (gToolbarWindow == -1 || !gShown) {
        return false;
    }
    return x >= gToolbarX && x < gToolbarX + toolbarWidth()
        && y >= gToolbarY && y < gToolbarY + kToolbarHeight;
}

bool quickToolbarHandleTap(int x, int y)
{
    if (!quickToolbarContainsPoint(x, y)) {
        return false;
    }

    // Prevent skill activation when the interface bar is disabled (e.g., during cutscenes).
    if (!interfaceBarEnabled() || gameUiIsDisabled()) {
        return true;
    }

    int localX = x - gToolbarX;
    int visibleIndex = -1;
    for (int i = 0; i < visibleButtonCount(); i++) {
        int entryIndex = visibleEntryIndex(i);
        int left = buttonX(i);
        if (localX >= left && localX < left + kButtons[entryIndex].width) {
            visibleIndex = i;
            break;
        }
    }
    if (visibleIndex == -1) {
        return true;
    }

    const ToolbarEntry& entry = kButtons[visibleEntryIndex(visibleIndex)];
    switch (entry.action) {
    case ToolbarAction::Settings:
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        falloutPresentIOSProductSettings();
#endif
        break;
    case ToolbarAction::Skills:
        displayMonitorAddMessage("Choose a skill.");
        enqueueInputEvent(KEY_LOWERCASE_S);
        break;
    case ToolbarAction::Cursor:
        gameMouseCycleMode();
        switch (gameMouseGetMode()) {
        case GAME_MOUSE_MODE_MOVE:
            displayMonitorAddMessage("Cursor mode: Move.");
            break;
        case GAME_MOUSE_MODE_ARROW:
            displayMonitorAddMessage("Cursor mode: Interact.");
            break;
        case GAME_MOUSE_MODE_CROSSHAIR:
            displayMonitorAddMessage("Cursor mode: Attack.");
            break;
        default:
            displayMonitorAddMessage("Cursor mode changed.");
            break;
        }
        break;
    case ToolbarAction::ItemAction: {
        interfaceCycleItemAction();
        int leftAction;
        int rightAction;
        interfaceGetItemActions(&leftAction, &rightAction);
        int action = interfaceGetCurrentHand() == 0 ? leftAction : rightAction;
        switch (action) {
        case INTERFACE_ITEM_ACTION_USE:
            displayMonitorAddMessage("Item action: Use.");
            break;
        case INTERFACE_ITEM_ACTION_PRIMARY:
            displayMonitorAddMessage("Item action: Primary attack.");
            break;
        case INTERFACE_ITEM_ACTION_PRIMARY_AIMING:
            displayMonitorAddMessage("Item action: Aimed attack.");
            break;
        case INTERFACE_ITEM_ACTION_SECONDARY:
            displayMonitorAddMessage("Item action: Secondary attack.");
            break;
        case INTERFACE_ITEM_ACTION_SECONDARY_AIMING:
            displayMonitorAddMessage("Item action: Aimed secondary attack.");
            break;
        case INTERFACE_ITEM_ACTION_RELOAD:
            displayMonitorAddMessage("Item action: Reload.");
            break;
        default:
            displayMonitorAddMessage("This item has no alternate action.");
            break;
        }
        break;
    }
    case ToolbarAction::EndTurn:
        if (interfaceBarEndButtonsAreEnabled()) {
            displayMonitorAddMessage("Turn ended.");
            enqueueInputEvent(KEY_SPACE);
        } else if (isInCombat()) {
            displayMonitorAddMessage("End Turn is available on your turn.");
        } else {
            displayMonitorAddMessage("End Turn is available during combat.");
        }
        break;
    case ToolbarAction::EndCombat:
        if (interfaceBarEndButtonsAreEnabled()) {
            displayMonitorAddMessage("End Combat requested.");
            enqueueInputEvent(KEY_RETURN);
        } else if (isInCombat()) {
            displayMonitorAddMessage("End Combat is available on your turn.");
        } else {
            displayMonitorAddMessage("End Combat is available during combat.");
        }
        break;
    }

    return true;
}

void quickToolbarRefresh()
{
    if (gToolbarWindow == -1) {
        return;
    }
    paintAll();
    windowRefresh(gToolbarWindow);
}

} // namespace fallout

#endif // defined(__APPLE__) && TARGET_OS_IOS
