The recording demonstrates a critical functional error where the game **Roof Groove (version 1.1.3)** crashes to the desktop without an error message.

### Error Details
*   **Error Type:** Application Crash / Silent Exit.
*   **Location:** Within the **ACCOUNT** sub-menu.
*   **Readable Text:** No explicit error code or text is displayed; the game window simply closes, returning the user to the Windows File Explorer.
*   **Timestamps:** The crash occurs twice in the video:
    *   **00:36:** After clicking the "ACCOUNT" button inside the Account menu for the first time.
    *   **01:11:** After re-entering the game, navigating back to the Account menu, and clicking the "ACCOUNT" button again.

### Reproduction Steps
1.  Launch `RoofGroove-Windows-Release-main.exe` (Version 1.1.3).
2.  Complete the initial "CHOOSE YOUR USERNAME" prompt (e.g., entering "vsdkla" or "caoUR").
3.  From the main menu, click the **ACCOUNT** button.
4.  Once in the Account sub-menu (which displays "Tokens: 85"), click the top button also labeled **ACCOUNT**.
5.  **Result:** The application immediately terminates.

### Clues & Observations
*   **UI Inconsistency:** At **00:12 - 00:22**, while in the **SETTINGS** menu, clicking the "MUSIC" checkbox fails to toggle it on, suggesting additional UI-related bugs in this build.
*   **Redundant Button:** The crash is triggered by clicking an "ACCOUNT" button while already inside the "ACCOUNT" menu, which may indicate a recursive call or a missing pointer to a profile page that hasn't been implemented, leading to the crash.