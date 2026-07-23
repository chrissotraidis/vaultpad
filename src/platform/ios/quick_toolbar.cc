#include "quick_toolbar.h"

#if defined(__APPLE__) && TARGET_OS_IOS

#include <stdio.h>
#include <string.h>

#include "../../animation.h"
#include "../../art.h"
#include "../../color.h"
#include "../../combat.h"
#include "../../display_monitor.h"
#include "../../draw.h"
#include "../../game.h"
#include "../../game_mouse.h"
#include "../../input.h"
#include "../../interface.h"
#include "../../item.h"
#include "../../kb.h"
#include "../../mouse.h"
#include "../../object.h"
#include "../../settings.h"
#include "../../svga.h"
#include "../../text_font.h"
#include "../../touch.h"
#include "../../window_manager.h"

namespace fallout {

#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
extern "C" void falloutPresentIOSProductSettings();
#endif

namespace {

    enum class ToolbarAction {
        MoveMode,
        UseMode,
        AttackMode,
        ItemAction,
        AlternateAction,
        EndTurn,
        Settings,
    };

    struct ToolbarEntry {
        ToolbarAction action;
        const char* label;
        int width;
        bool startsGroup;
    };

    // Fallout already exposes Skills and combat turn controls in its HUD. The
    // touch bar only supplies commands that otherwise require a mouse button or
    // hidden gesture, with explicit mode choices instead of a cycling cursor.
    constexpr ToolbarEntry kButtons[] = {
        { ToolbarAction::MoveMode, "Move", 38, false },
        { ToolbarAction::UseMode, "Use", 34, false },
        { ToolbarAction::AttackMode, "Attack", 50, false },
        { ToolbarAction::ItemAction, nullptr, 96, true },
        { ToolbarAction::AlternateAction, nullptr, 108, false },
        { ToolbarAction::EndTurn, nullptr, 62, true },
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        { ToolbarAction::Settings, nullptr, 46, true },
#endif
    };

    constexpr int kButtonCount = sizeof(kButtons) / sizeof(kButtons[0]);
    constexpr int kButtonHeight = 24;
    constexpr int kCollapsedButtonHeight = 22;
    constexpr int kButtonGap = 1;
    constexpr int kGroupGap = 4;
    constexpr int kPanelPadding = 2;
    constexpr int kToolbarBottomMargin = 2;
    constexpr int kCollapsedRightMargin = 10;

    int gToolbarWindow = -1;
    int gToolbarX = 0;
    int gToolbarY = 0;
    int gToolbarWidth = 0;
    bool gShown = false;
    bool gEnabled = true;
    bool gMovementModeInitialized = false;
    bool gMovementRuns = false;

    void ensureMovementModeInitialized()
    {
        if (!gMovementModeInitialized) {
            gMovementRuns = settings.preferences.running;
            gMovementModeInitialized = true;
        }
    }

    int currentButtonHeight()
    {
        return gEnabled ? kButtonHeight : kCollapsedButtonHeight;
    }

    int currentToolbarHeight()
    {
        return currentButtonHeight() + kPanelPadding * 2;
    }

    bool entryIsVisible(int entryIndex)
    {
#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
        if (!gEnabled) {
            return kButtons[entryIndex].action == ToolbarAction::Settings;
        }
#endif
        ToolbarAction action = kButtons[entryIndex].action;
        return (action != ToolbarAction::AttackMode && action != ToolbarAction::EndTurn) || isInCombat();
    }

    int visibleButtonCount()
    {
        int count = 0;
        for (int entryIndex = 0; entryIndex < kButtonCount; entryIndex++) {
            if (entryIsVisible(entryIndex)) {
                count++;
            }
        }
        return count;
    }

    int visibleEntryIndex(int visibleIndex)
    {
        for (int entryIndex = 0; entryIndex < kButtonCount; entryIndex++) {
            if (!entryIsVisible(entryIndex)) {
                continue;
            }
            if (visibleIndex == 0) {
                return entryIndex;
            }
            visibleIndex--;
        }
        return -1;
    }

    int buttonX(int visibleIndex)
    {
        int x = kPanelPadding;
        for (int i = 0; i < visibleIndex; i++) {
            int entryIndex = visibleEntryIndex(i);
            x += kButtons[entryIndex].width;
            int nextEntryIndex = visibleEntryIndex(i + 1);
            x += kButtons[nextEntryIndex].startsGroup ? kGroupGap : kButtonGap;
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
        return buttonX(lastVisibleIndex) + kButtons[lastEntryIndex].width + kPanelPadding;
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

    struct CurrentAttack {
        const char* name;
        int actionPoints;
        bool aiming;
        bool valid;
    };

    const char* attackNameForHitMode(int hitMode)
    {
        switch (hitMode) {
        case HIT_MODE_PUNCH:
            return "Punch";
        case HIT_MODE_KICK:
            return "Kick";
        case HIT_MODE_STRONG_PUNCH:
            return "Strong Punch";
        case HIT_MODE_HAMMER_PUNCH:
            return "Hammer Punch";
        case HIT_MODE_HAYMAKER:
            return "Lightning Punch";
        case HIT_MODE_JAB:
            return "Chop Punch";
        case HIT_MODE_PALM_STRIKE:
            return "Dragon Punch";
        case HIT_MODE_PIERCING_STRIKE:
            return "Force Punch";
        case HIT_MODE_STRONG_KICK:
            return "Strong Kick";
        case HIT_MODE_SNAP_KICK:
            return "Snap Kick";
        case HIT_MODE_POWER_KICK:
            return "Roundhouse";
        case HIT_MODE_HIP_KICK:
            return "Hip Kick";
        case HIT_MODE_HOOK_KICK:
            return "Jump Kick";
        case HIT_MODE_PIERCING_KICK:
            return "Death Blossom";
        default:
            break;
        }

        if (gDude != nullptr) {
            switch (critterGetAnimationForHitMode(gDude, hitMode)) {
            case ANIM_THROW_ANIM:
                return "Throw";
            case ANIM_THRUST_ANIM:
                return "Thrust";
            case ANIM_SWING_ANIM:
                return "Swing";
            case ANIM_FIRE_SINGLE:
                return "Single Shot";
            case ANIM_FIRE_BURST:
            case ANIM_FIRE_CONTINUOUS:
                return "Burst";
            default:
                break;
            }
        }

        return "Attack";
    }

    CurrentAttack attackForHand(int hand)
    {
        int hitMode = HIT_MODE_PUNCH;
        bool aiming = false;
        if (gDude == nullptr || interfaceGetHitModeForHand(hand, &hitMode, &aiming) == -1) {
            return { "Attack", 0, false, false };
        }

        return {
            attackNameForHitMode(hitMode),
            itemGetActionPointCost(gDude, hitMode, aiming),
            aiming,
            true,
        };
    }

    CurrentAttack currentAttack()
    {
        return attackForHand(interfaceGetCurrentHand());
    }

    void showAttackGuidance()
    {
        CurrentAttack attack = currentAttack();
        if (!attack.valid) {
            displayMonitorAddMessage("Choose an attack action first.");
            return;
        }

        static char message[128];
        int availableActionPoints = gDude != nullptr ? gDude->data.critter.combat.ap : 0;
        if (isInCombat() && attack.actionPoints > availableActionPoints) {
            snprintf(message, sizeof(message), "%s costs %d action points; you have %d. Choose End Turn.", attack.name, attack.actionPoints, availableActionPoints);
        } else if (attack.aiming) {
            snprintf(message, sizeof(message), "Aimed %s costs %d action points. Pick a body part; it can still miss.", attack.name, attack.actionPoints);
        } else {
            snprintf(message, sizeof(message), "%s costs %d action points. The target percentage is your chance to hit.", attack.name, attack.actionPoints);
        }
        displayMonitorAddMessage(message);
    }

    const char* itemActionLabel()
    {
        // The game's main HUD action is the clearest source of truth. Checking
        // the raw left/right item state first can report "Use Item" while the
        // visible HUD and cursor are actually set to Punch.
        CurrentAttack attack = currentAttack();
        if (attack.valid) {
            return attack.name;
        }

        int leftAction;
        int rightAction;
        interfaceGetItemActions(&leftAction, &rightAction);
        int action = interfaceGetCurrentHand() == 0 ? leftAction : rightAction;
        switch (action) {
        case INTERFACE_ITEM_ACTION_USE:
            return "Use Item";
        case INTERFACE_ITEM_ACTION_RELOAD:
            return "Reload";
        default:
            break;
        }

        return "Action";
    }

    const char* alternateActionLabel()
    {
        int otherHand = interfaceGetCurrentHand() == 0 ? 1 : 0;
        CurrentAttack attack = attackForHand(otherHand);
        if (attack.valid) {
            return attack.name;
        }

        int leftAction;
        int rightAction;
        interfaceGetItemActions(&leftAction, &rightAction);
        int action = otherHand == 0 ? leftAction : rightAction;
        if (action == INTERFACE_ITEM_ACTION_USE) {
            return "Other item";
        }
        if (action == INTERFACE_ITEM_ACTION_RELOAD) {
            return "Other weapon";
        }
        return "Other action";
    }

    const char* entryLabel(const ToolbarEntry& entry)
    {
        if (entry.action == ToolbarAction::MoveMode) {
            ensureMovementModeInitialized();
            return gMovementRuns ? "Run" : "Walk";
        }
        if (entry.action == ToolbarAction::ItemAction) {
            return itemActionLabel();
        }
        if (entry.action == ToolbarAction::AlternateAction) {
            return alternateActionLabel();
        }
        return entry.label;
    }

    bool entryIsSelected(const ToolbarEntry& entry)
    {
        int mode = gameMouseGetMode();
        switch (entry.action) {
        case ToolbarAction::MoveMode:
            return mode == GAME_MOUSE_MODE_MOVE;
        case ToolbarAction::UseMode:
            return mode == GAME_MOUSE_MODE_ARROW;
        case ToolbarAction::AttackMode:
            return mode == GAME_MOUSE_MODE_CROSSHAIR;
        default:
            return false;
        }
    }

    void paintSettingsCog(unsigned char* buffer, int pitch, int centerX, int centerY, unsigned char metal, unsigned char hole)
    {
        // A 13x13 pixel cog: eight visible teeth, a compact body, and a dark
        // center bore. Keeping it this geometric makes it survive iPad scaling.
        fillRect(buffer, pitch, centerX - 4, centerY - 4, 9, 9, metal);
        fillRect(buffer, pitch, centerX - 1, centerY - 6, 3, 2, metal);
        fillRect(buffer, pitch, centerX - 1, centerY + 5, 3, 2, metal);
        fillRect(buffer, pitch, centerX - 6, centerY - 1, 2, 3, metal);
        fillRect(buffer, pitch, centerX + 5, centerY - 1, 2, 3, metal);
        fillRect(buffer, pitch, centerX - 5, centerY - 5, 2, 2, metal);
        fillRect(buffer, pitch, centerX + 4, centerY - 5, 2, 2, metal);
        fillRect(buffer, pitch, centerX - 5, centerY + 4, 2, 2, metal);
        fillRect(buffer, pitch, centerX + 4, centerY + 4, 2, 2, metal);
        fillRect(buffer, pitch, centerX - 2, centerY - 2, 5, 5, hole);
    }

    void paintVaultPadBadge(unsigned char* buffer, int pitch, int x, int y, int w, int h)
    {
        // A tiny riveted field-terminal badge, derived from the VaultPad visual
        // language but rendered in Fallout's own palette and pixel font. It is
        // deliberately an icon inside the button, not another text command.
        int badgeX = x + 5;
        int badgeY = y + 4;
        int badgeWidth = w - 10;
        int badgeHeight = h - 8;
        unsigned char face = intensityColorTable[COLOR_DULL_BROWN][12];
        unsigned char brass = intensityColorTable[COLOR_LIGHT_GOLD_2][52];
        unsigned char shadow = intensityColorTable[COLOR_DARK_BROWN][70];
        unsigned char letters = intensityColorTable[COLOR_LIGHT_GOLD_2][94];

        fillRect(buffer, pitch, badgeX, badgeY, badgeWidth, badgeHeight, face);
        fillRect(buffer, pitch, badgeX, badgeY, badgeWidth, 1, brass);
        fillRect(buffer, pitch, badgeX, badgeY, 1, badgeHeight, brass);
        fillRect(buffer, pitch, badgeX, badgeY + badgeHeight - 1, badgeWidth, 1, shadow);
        fillRect(buffer, pitch, badgeX + badgeWidth - 1, badgeY, 1, badgeHeight, shadow);

        // Clip the four corners so this remains a small field-terminal plate.
        buffer[badgeY * pitch + badgeX] = face;
        buffer[badgeY * pitch + badgeX + badgeWidth - 1] = face;
        buffer[(badgeY + badgeHeight - 1) * pitch + badgeX] = face;
        buffer[(badgeY + badgeHeight - 1) * pitch + badgeX + badgeWidth - 1] = face;

        int centerY = badgeY + badgeHeight / 2;
        paintSettingsCog(buffer, pitch, badgeX + 8, centerY, brass, face);
        drawCenteredLabel(buffer, pitch, badgeX + 18, badgeY, badgeWidth - 18, badgeHeight, "VP", letters);
    }

    void paintCurrentAction(unsigned char* buffer, int pitch, int x, int y, int w, int h, unsigned char color)
    {
        CurrentAttack attack = currentAttack();
        if (!attack.valid) {
            drawCenteredLabel(buffer, pitch, x, y, w, h, itemActionLabel(), color);
            return;
        }

        // The action name and its cost are different pieces of information.
        // Giving each its own line keeps every unarmed and weapon name intact
        // instead of clipping prose such as "Aim Punch - Cost 4".
        char detail[32];
        snprintf(detail, sizeof(detail), attack.aiming ? "Aimed | %d AP" : "Normal | %d AP", attack.actionPoints);

        int halfHeight = h / 2;
        drawCenteredLabel(buffer, pitch, x + 2, y, w - 4, halfHeight + 1, attack.name, color);
        drawCenteredLabel(buffer, pitch, x + 2, y + halfHeight - 1, w - 4, h - halfHeight + 1, detail, color);
    }

    void paintTwoLineLabel(unsigned char* buffer, int pitch, int x, int y, int w, int h, const char* top, const char* bottom, unsigned char color)
    {
        int halfHeight = h / 2;
        drawCenteredLabel(buffer, pitch, x + 2, y, w - 4, halfHeight + 1, top, color);
        drawCenteredLabel(buffer, pitch, x + 2, y + halfHeight - 1, w - 4, h - halfHeight + 1, bottom, color);
    }

    void paintPanelButton(unsigned char* buffer, int pitch, int x, int y, int w, int h, const ToolbarEntry& entry, bool selected)
    {
        unsigned char panel = selected
            ? intensityColorTable[COLOR_DULL_BROWN][32]
            : intensityColorTable[COLOR_DULL_BROWN][18];
        unsigned char topBorder = selected
            ? intensityColorTable[COLOR_LIGHT_GOLD_2][72]
            : intensityColorTable[COLOR_OLIVE][38];
        unsigned char bottomBorder = intensityColorTable[COLOR_DARK_BROWN][selected ? 64 : 44];

        fillRect(buffer, pitch, x, y, w, h, panel);
        fillRect(buffer, pitch, x, y, w, 1, topBorder);
        fillRect(buffer, pitch, x, y, 1, h, topBorder);
        fillRect(buffer, pitch, x, y + h - 1, w, 1, bottomBorder);
        if (selected && w > 4 && h > 4) {
            fillRect(buffer, pitch, x + 2, y + 2, w - 4, 1, intensityColorTable[COLOR_LIGHT_GOLD_2][42]);
        }
        fillRect(buffer, pitch, x + w - 1, y, 1, h, bottomBorder);

        if (entry.action == ToolbarAction::Settings) {
            paintVaultPadBadge(buffer, pitch, x, y, w, h);
        } else if (entry.action == ToolbarAction::ItemAction) {
            paintCurrentAction(buffer, pitch, x, y, w, h, intensityColorTable[COLOR_LIGHT_GOLD_2][selected ? 92 : 58]);
        } else if (entry.action == ToolbarAction::AlternateAction) {
            paintTwoLineLabel(buffer, pitch, x, y, w, h, "Switch to", entryLabel(entry), intensityColorTable[COLOR_LIGHT_GOLD_2][selected ? 92 : 58]);
        } else if (entry.action == ToolbarAction::EndTurn) {
            paintTwoLineLabel(buffer, pitch, x, y, w, h, "End", "Turn", intensityColorTable[COLOR_LIGHT_GOLD_2][selected ? 92 : 58]);
        } else {
            drawCenteredLabel(buffer, pitch, x, y, w, h, entryLabel(entry), intensityColorTable[COLOR_LIGHT_GOLD_2][selected ? 92 : 58]);
        }
    }

    void paintAll()
    {
        unsigned char* buffer = windowGetBuffer(gToolbarWindow);
        if (buffer == nullptr) {
            return;
        }

        int width = gToolbarWidth;
        int toolbarHeight = currentToolbarHeight();
        unsigned char frame = intensityColorTable[COLOR_DULL_BROWN][26];
        unsigned char frameHighlight = intensityColorTable[COLOR_OLIVE][40];
        unsigned char frameShadow = intensityColorTable[COLOR_DARK_BROWN][62];
        fillRect(buffer, width, 0, 0, width, toolbarHeight, frame);
        fillRect(buffer, width, 0, 0, width, 1, frameHighlight);
        fillRect(buffer, width, 0, 0, 1, toolbarHeight, frameHighlight);
        fillRect(buffer, width, 0, toolbarHeight - 1, width, 1, frameShadow);
        fillRect(buffer, width, width - 1, 0, 1, toolbarHeight, frameShadow);

        int oldFont = fontGetCurrent();
        fontSetCurrent(101);

        int buttonHeight = currentButtonHeight();
        int buttonY = (toolbarHeight - buttonHeight) / 2;
        for (int visibleIndex = 0; visibleIndex < visibleButtonCount(); visibleIndex++) {
            int entryIndex = visibleEntryIndex(visibleIndex);
            const ToolbarEntry& entry = kButtons[entryIndex];
            paintPanelButton(buffer, width, buttonX(visibleIndex), buttonY, entry.width, buttonHeight, entry, entryIsSelected(entry));
        }

        fontSetCurrent(oldFont);
    }

    // WINDOW_TRANSPARENT makes palette-0 (black) pixels composite away, so the
    // empty space around and between buttons is see-through. The button panels
    // themselves use a non-black dim gray so they still render as raised tiles.
    void createWindow()
    {
        gToolbarWidth = toolbarWidth();
        if (gToolbarWidth == 0) {
            return;
        }
        gToolbarX = gEnabled
            ? (screenGetWidth() - gToolbarWidth) / 2
            : screenGetWidth() - gToolbarWidth - kCollapsedRightMargin;
        // Fallout uses the row directly above the HUD for status indicators
        // such as ADDICT and SNEAK. Keep the touch dock clear of that row.
        gToolbarY = screenGetHeight() - INTERFACE_BAR_HEIGHT - INDICATOR_BOX_HEIGHT - currentToolbarHeight() - kToolbarBottomMargin;

        gToolbarWindow = windowCreate(gToolbarX, gToolbarY, gToolbarWidth, currentToolbarHeight(), COLOR_BLACK, WINDOW_HIDDEN | WINDOW_TRANSPARENT);
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
        gToolbarWidth = 0;
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

    // Modal screens own every tap until they close. This prevents a Skilldex
    // Cancel tap (or a tap outside another dialog) from activating a toolbar
    // button behind it.
    constexpr int allowedModes = GameMode::kCombat | GameMode::kPlayerTurn;
    if ((GameMode::getCurrentGameMode() & ~allowedModes) != 0) {
        return false;
    }

    return windowGetAtPoint(x, y) == gToolbarWindow
        && x >= gToolbarX && x < gToolbarX + gToolbarWidth
        && y >= gToolbarY && y < gToolbarY + currentToolbarHeight();
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
    case ToolbarAction::MoveMode:
        ensureMovementModeInitialized();
        if (gameMouseGetMode() == GAME_MOUSE_MODE_MOVE) {
            gMovementRuns = !gMovementRuns;
        } else {
            gameMouseSetMode(GAME_MOUSE_MODE_MOVE);
        }
        displayMonitorAddMessage(gMovementRuns
                ? "Run selected. Tap the ground; tap Run again to walk."
                : "Walk selected. Tap the ground; tap Walk again to run.");
        quickToolbarRefresh();
        break;
    case ToolbarAction::UseMode:
        gameMouseSetMode(GAME_MOUSE_MODE_ARROW);
        displayMonitorAddMessage("Interaction selected. Tap a person, door, or object.");
        break;
    case ToolbarAction::AttackMode: {
        showAttackGuidance();
        // Always arm targeting. Fallout remains the source of truth for range
        // and action-point checks, while the dock never appears stuck in Walk
        // or Use just because the current attack is temporarily unavailable.
        gameMouseSetMode(GAME_MOUSE_MODE_CROSSHAIR);
        break;
    }
    case ToolbarAction::ItemAction: {
        interfaceCycleItemAction();
        int leftAction;
        int rightAction;
        interfaceGetItemActions(&leftAction, &rightAction);
        int action = interfaceGetCurrentHand() == 0 ? leftAction : rightAction;
        switch (action) {
        case INTERFACE_ITEM_ACTION_USE:
            displayMonitorAddMessage("Item set to use.");
            break;
        case INTERFACE_ITEM_ACTION_RELOAD:
            displayMonitorAddMessage("Weapon set to reload.");
            break;
        default:
            showAttackGuidance();
            gameMouseSetMode(GAME_MOUSE_MODE_CROSSHAIR);
            break;
        }
        quickToolbarRefresh();
        break;
    }
    case ToolbarAction::AlternateAction:
        if (interfaceBarSwapHands(false) == 0) {
            CurrentAttack attack = currentAttack();
            static char message[128];
            if (attack.valid) {
                snprintf(message, sizeof(message), "%s selected. Tap a target; it costs %d action points.", attack.name, attack.actionPoints);
                displayMonitorAddMessage(message);
                gameMouseSetMode(GAME_MOUSE_MODE_CROSSHAIR);
            } else {
                displayMonitorAddMessage("Alternate item selected.");
            }
            quickToolbarRefresh();
        }
        break;
    case ToolbarAction::EndTurn:
        if (interfaceBarEndButtonsAreEnabled()) {
            displayMonitorAddMessage("Turn ended. Enemies act next; your action points refill afterward.");
            enqueueInputEvent(KEY_SPACE);
        } else {
            displayMonitorAddMessage("End Turn is available when it is your turn.");
        }
        break;
    }

    return true;
}

bool quickToolbarShouldRunMovement(bool shiftHeld, bool defaultRunning)
{
    if (!gEnabled) {
        return shiftHeld ? !defaultRunning : defaultRunning;
    }

    ensureMovementModeInitialized();
    return shiftHeld ? !gMovementRuns : gMovementRuns;
}

void quickToolbarRefresh()
{
    if (gToolbarWindow == -1) {
        return;
    }
    if (toolbarWidth() != gToolbarWidth) {
        bool wasShown = gShown;
        destroyWindow();
        gShown = false;
        if (wasShown) {
            quickToolbarShow();
        }
        return;
    }
    paintAll();
    windowRefresh(gToolbarWindow);
}

#ifdef FALLOUT_IOS_PRODUCT_BOOTSTRAP
extern "C" void falloutApplyIOSTouchSettings(const char* touchMode, double sensitivity, int toolbarEnabled)
{
    if (touchMode != nullptr) {
        settings.input.touch_mode = touchMode;
    }
    settings.input.touch_sensitivity = sensitivity;
    settings.ui.quick_toolbar_visible = toolbarEnabled != 0;
    quickToolbarSetEnabled(settings.ui.quick_toolbar_visible);

    // Re-applying the current game cursor mode updates direct-vs-trackpad
    // routing and refreshes the command bar's selected state immediately.
    gameMouseSetMode(gameMouseGetMode());
}

extern "C" void falloutResetIOSTouchState()
{
    touch_reset_to_direct_context();
}
#endif

} // namespace fallout

#endif // defined(__APPLE__) && TARGET_OS_IOS
