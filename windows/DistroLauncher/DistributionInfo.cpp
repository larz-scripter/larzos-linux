//
// LarzOS WSL launcher - user account handling.
// Forked from Microsoft's WSL-DistroLauncher (MIT). See LICENSE.
//

#include "stdafx.h"

bool DistributionInfo::CreateUser(std::wstring_view userName)
{
    DWORD exitCode;

    // The LarzOS rootfs already carries this account at uid 1000. If it is
    // there, nothing to do - this keeps the launcher working against both the
    // current rootfs and any older one that shipped without the user.
    if (QueryUid(userName) != UID_INVALID) {
        return true;
    }

    std::wstring commandLine = L"/usr/sbin/useradd --create-home --user-group ";
    commandLine += L"--groups sudo,adm,cdrom,dip,plugdev --shell /bin/bash ";
    commandLine += userName;
    HRESULT hr = g_wslApi.WslLaunchInteractive(commandLine.c_str(), true, &exitCode);
    if ((FAILED(hr)) || (exitCode != 0)) {
        return false;
    }

    // Passwordless sudo, matching how the rootfs configures `larz`.
    std::wstring sudoers = L"/bin/sh -c \"echo '";
    sudoers += userName;
    sudoers += L" ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-larzos && chmod 440 /etc/sudoers.d/90-larzos\"";
    g_wslApi.WslLaunchInteractive(sudoers.c_str(), true, &exitCode);

    return true;
}

ULONG DistributionInfo::QueryUid(std::wstring_view userName)
{
    // Create a pipe to read the output of the launched process.
    HANDLE readPipe;
    HANDLE writePipe;
    SECURITY_ATTRIBUTES sa{sizeof(sa), nullptr, true};
    ULONG uid = UID_INVALID;
    if (CreatePipe(&readPipe, &writePipe, &sa, 0)) {
        // Query the UID of the supplied username.
        std::wstring command = L"/usr/bin/id -u ";
        command += userName;
        int returnValue = 0;
        HANDLE child;
        HRESULT hr = g_wslApi.WslLaunch(command.c_str(), true, GetStdHandle(STD_INPUT_HANDLE), writePipe, GetStdHandle(STD_ERROR_HANDLE), &child);
        if (SUCCEEDED(hr)) {
            // Wait for the child to exit and ensure process exited successfully.
            WaitForSingleObject(child, INFINITE);
            DWORD exitCode;
            if ((GetExitCodeProcess(child, &exitCode) == false) || (exitCode != 0)) {
                hr = E_INVALIDARG;
            }

            CloseHandle(child);
            if (SUCCEEDED(hr)) {
                char buffer[64];
                DWORD bytesRead;

                // Read the output of the command from the pipe and convert to a UID.
                if (ReadFile(readPipe, buffer, (sizeof(buffer) - 1), &bytesRead, nullptr)) {
                    buffer[bytesRead] = ANSI_NULL;
                    try {
                        uid = std::stoul(buffer, nullptr, 10);

                    } catch( ... ) { }
                }
            }
        }

        CloseHandle(readPipe);
        CloseHandle(writePipe);
    }

    return uid;
}
