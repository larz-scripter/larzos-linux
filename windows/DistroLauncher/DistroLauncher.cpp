//
// LarzOS WSL launcher.
// Forked from Microsoft's WSL-DistroLauncher (MIT). See LICENSE.
//
// Double-click LarzOS.exe (with install.tar.gz beside it) to register LarzOS
// as a WSL distribution, or run:
//     LarzOS.exe install [--root]
//     LarzOS.exe run <command>
//     LarzOS.exe config --default-user <name>
//

#include "stdafx.h"

// Commandline arguments:
#define ARG_CONFIG              L"config"
#define ARG_CONFIG_DEFAULT_USER L"--default-user"
#define ARG_INSTALL             L"install"
#define ARG_INSTALL_ROOT        L"--root"
#define ARG_RUN                 L"run"
#define ARG_RUN_C               L"-c"

// Helper class for calling the WSL API (wslapi.dll), loaded on demand.
WslApiLoader g_wslApi(DistributionInfo::Name);

static HRESULT InstallDistribution(bool createUser);
static HRESULT SetDefaultUser(std::wstring_view userName);

// --- First-run engine setup ------------------------------------------------
//
// LarzOS is meant to work on a PC that has never had WSL. The Linux engine is
// a Windows component (Virtual Machine Platform + the WSL runtime); it can't be
// bundled outright, but LarzOS can turn it on itself: `wsl.exe --install` (a
// system stub on every Windows 10 2004+/11) self-elevates, enables the feature
// and installs the runtime in one step. A `wsl.msi` shipped next to LarzOS.exe
// is the offline fallback. Either way the machine needs one reboot the first
// time, after which every LarzOS launch is instant.

enum class EngineState { Present, JustEnabled, NeedsReboot, Failed };

static std::wstring ExeDir()
{
    wchar_t buf[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, buf, ARRAYSIZE(buf));
    std::wstring path(buf);
    const auto slash = path.find_last_of(L"\\/");
    return (slash == std::wstring::npos) ? L"." : path.substr(0, slash);
}

static bool RunAndWait(const std::wstring& commandLine, DWORD* exitCode)
{
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    std::wstring mutableCmd = commandLine;
    if (!CreateProcessW(nullptr, mutableCmd.data(), nullptr, nullptr, FALSE,
                        0, nullptr, nullptr, &si, &pi)) {
        return false;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    if (exitCode != nullptr) {
        GetExitCodeProcess(pi.hProcess, exitCode);
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return true;
}

static bool EnginePresent()
{
    WslApiLoader probe(DistributionInfo::Name);
    return probe.WslIsOptionalComponentInstalled() != FALSE;
}

static EngineState EnsureEngine()
{
    if (EnginePresent()) {
        return EngineState::Present;
    }

    Helpers::PrintMessage(MSG_ENGINE_SETUP_STARTING);

    DWORD ec = 1;
    bool anyStepRan = false;
    const std::wstring msi = ExeDir() + L"\\wsl.msi";
    const bool haveMsi =
        GetFileAttributesW(msi.c_str()) != INVALID_FILE_ATTRIBUTES;

    if (haveMsi) {
        // Fully-offline path: the Virtual Machine Platform feature ships in the
        // OS (DISM needs no network) and the WSL runtime is the bundled MSI.
        // Both steps run elevated via one UAC prompt each.
        anyStepRan |= RunAndWait(
            L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
            L"\"Start-Process dism.exe -Verb RunAs -Wait -ArgumentList "
            L"'/online','/enable-feature','/featurename:VirtualMachinePlatform',"
            L"'/all','/norestart'\"", &ec);
        anyStepRan |= RunAndWait(
            L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
            L"\"Start-Process msiexec.exe -Verb RunAs -Wait "
            L"-ArgumentList '/i',(Resolve-Path '" + msi + L"'),'/passive'\"", &ec);
    }

    // Windows' own bootstrapper (needs network) - used when there's no bundled
    // MSI, or as a backstop if the offline steps didn't take.
    if (!EnginePresent()) {
        anyStepRan |= RunAndWait(L"wsl.exe --install --no-distribution", &ec);
    }

    if (EnginePresent()) {
        return EngineState::JustEnabled;   // rare: no reboot needed
    }
    if (!anyStepRan) {
        return EngineState::Failed;        // couldn't even start a setup step
    }
    // A setup step ran; the feature is enabled but needs a reboot to load.
    return EngineState::NeedsReboot;
}

// True when LarzOS.exe is running from inside its installed MSIX package.
static bool RunningPackaged()
{
    UINT32 len = 0;
    return GetCurrentPackageFullName(&len, nullptr) != APPMODEL_ERROR_NO_PACKAGE;
}

// What a shortcut / RunOnce entry should launch. For the MSIX it is the
// `larzos.exe` execution alias (a stable path that survives app updates); for
// the loose build it is this executable.
static std::wstring LaunchTarget()
{
    if (RunningPackaged()) {
        wchar_t local[MAX_PATH] = {};
        if (GetEnvironmentVariableW(L"LOCALAPPDATA", local, ARRAYSIZE(local))) {
            return std::wstring(local) + L"\\Microsoft\\WindowsApps\\larzos.exe";
        }
    }
    wchar_t self[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, self, ARRAYSIZE(self));
    return self;
}

// Put a "LarzOS" icon on the desktop so there is an obvious thing to click,
// especially after the first-run reboot. Idempotent - overwrites its own .lnk.
static void EnsureDesktopIcon()
{
    const std::wstring target = LaunchTarget();
    wchar_t self[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, self, ARRAYSIZE(self));

    std::wstring ps =
        L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \""
        L"$s=(New-Object -ComObject WScript.Shell); "
        L"$lnk=$s.CreateShortcut([IO.Path]::Combine([Environment]::GetFolderPath('Desktop'),'LarzOS.lnk')); "
        L"$lnk.TargetPath='" + target + L"'; "
        L"$lnk.IconLocation='" + std::wstring(self) + L",0'; "
        L"$lnk.Description='Open LarzOS'; $lnk.Save()\"";

    DWORD ec = 0;
    RunAndWait(ps, &ec);
}

// Re-open LarzOS automatically after the first-run reboot.
static void SetResumeAfterReboot()
{
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER,
            L"Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
            0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        return;
    }
    const std::wstring value = L"\"" + LaunchTarget() + L"\"";
    RegSetValueExW(key, L"LarzOS", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(value.c_str()),
                   static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
}

// Relaunch a fresh copy of this exe (so a newly-present wslapi.dll is loaded)
// and let it take over. Fire and forget - this process then exits.
static void RelaunchSelf()
{
    wchar_t self[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, self, ARRAYSIZE(self));
    std::wstring cmd = L"\"";
    cmd += self;
    cmd += L"\"";
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    if (CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                       CREATE_NEW_CONSOLE, nullptr, nullptr, &si, &pi)) {
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }
}

HRESULT InstallDistribution(bool createUser)
{
    // Register the distribution from install.tar.gz next to this executable.
    Helpers::PrintMessage(MSG_STATUS_INSTALLING);
    HRESULT hr = g_wslApi.WslRegisterDistribution();
    if (FAILED(hr)) {
        return hr;
    }

    // Drop /etc/resolv.conf so WSL regenerates it from Windows networking.
    DWORD exitCode;
    hr = g_wslApi.WslLaunchInteractive(L"/bin/rm -f /etc/resolv.conf", true, &exitCode);
    if (FAILED(hr)) {
        return hr;
    }

    // The LarzOS rootfs ships the `larz` account (uid 1000) already. Make it
    // the default unless the caller asked to stay as root. No username prompt.
    if (createUser) {
        if (!DistributionInfo::CreateUser(DistributionInfo::DefaultUser)) {
            return E_INVALIDARG;
        }

        hr = SetDefaultUser(DistributionInfo::DefaultUser);
        if (FAILED(hr)) {
            return hr;
        }
    }

    return hr;
}

HRESULT SetDefaultUser(std::wstring_view userName)
{
    ULONG uid = DistributionInfo::QueryUid(userName);
    if (uid == UID_INVALID) {
        return E_INVALIDARG;
    }

    HRESULT hr = g_wslApi.WslConfigureDistribution(uid, WSL_DISTRIBUTION_FLAGS_DEFAULT);
    if (FAILED(hr)) {
        return hr;
    }

    return hr;
}

int wmain(int argc, wchar_t const *argv[])
{
    // Update the title bar of the console window.
    SetConsoleTitleW(DistributionInfo::WindowTitle.c_str());

    // Initialize a vector of arguments.
    std::vector<std::wstring_view> arguments;
    for (int index = 1; index < argc; index += 1) {
        arguments.push_back(argv[index]);
    }

    // Ensure the Windows Linux engine is present, setting it up on first run.
    DWORD exitCode = 1;
    if (!g_wslApi.WslIsOptionalComponentInstalled()) {
        switch (EnsureEngine()) {
        case EngineState::Present:        // stale global; a fresh process sees it
        case EngineState::JustEnabled:
            Helpers::PrintMessage(MSG_ENGINE_READY_RELAUNCH);
            RelaunchSelf();
            return 0;
        case EngineState::NeedsReboot:
            EnsureDesktopIcon();
            SetResumeAfterReboot();
            Helpers::PrintMessage(MSG_ENGINE_SETUP_REBOOT);
            if (arguments.empty()) {
                Helpers::PromptForInput();
            }
            return 0;
        case EngineState::Failed:
        default:
            Helpers::PrintMessage(MSG_ENGINE_SETUP_FAILED);
            if (arguments.empty()) {
                Helpers::PromptForInput();
            }
            return exitCode;
        }
    }

    // Install the distribution if it is not already.
    bool installOnly = ((arguments.size() > 0) && (arguments[0] == ARG_INSTALL));
    HRESULT hr = S_OK;
    if (!g_wslApi.WslIsDistributionRegistered()) {

        // If the "--root" option is specified, do not set a default user.
        bool useRoot = ((installOnly) && (arguments.size() > 1) && (arguments[1] == ARG_INSTALL_ROOT));
        hr = InstallDistribution(!useRoot);
        if (FAILED(hr)) {
            if (hr == HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS)) {
                Helpers::PrintMessage(MSG_INSTALL_ALREADY_EXISTS);
            }

        } else {
            EnsureDesktopIcon();
            Helpers::PrintMessage(MSG_INSTALL_SUCCESS);
        }

        exitCode = SUCCEEDED(hr) ? 0 : 1;
    }

    // Parse the command line arguments.
    if ((SUCCEEDED(hr)) && (!installOnly)) {
        if (arguments.empty()) {
            hr = g_wslApi.WslLaunchInteractive(L"", false, &exitCode);

            // Check exitCode to see if wsl.exe returned that it could not start
            // the Linux process, then prompt so the user can read the error.
            if (SUCCEEDED(hr) && exitCode == UINT_MAX) {
                Helpers::PromptForInput();
            }

        } else if ((arguments[0] == ARG_RUN) ||
                   (arguments[0] == ARG_RUN_C)) {

            std::wstring command;
            for (size_t index = 1; index < arguments.size(); index += 1) {
                command += L" ";
                command += arguments[index];
            }

            hr = g_wslApi.WslLaunchInteractive(command.c_str(), true, &exitCode);

        } else if (arguments[0] == ARG_CONFIG) {
            hr = E_INVALIDARG;
            if (arguments.size() == 3) {
                if (arguments[1] == ARG_CONFIG_DEFAULT_USER) {
                    hr = SetDefaultUser(arguments[2]);
                }
            }

            if (SUCCEEDED(hr)) {
                exitCode = 0;
            }

        } else {
            Helpers::PrintMessage(MSG_USAGE);
            return exitCode;
        }
    }

    // If an error was encountered, print an error message.
    if (FAILED(hr)) {
        if (hr == HCS_E_HYPERV_NOT_INSTALLED) {
            Helpers::PrintMessage(MSG_ENABLE_VIRTUALIZATION);

        } else {
            Helpers::PrintErrorMessage(hr);
        }

        if (arguments.empty()) {
            Helpers::PromptForInput();
        }
    }

    return SUCCEEDED(hr) ? exitCode : 1;
}
