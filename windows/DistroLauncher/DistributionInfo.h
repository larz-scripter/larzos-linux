//
// LarzOS WSL launcher.
//
// Forked from Microsoft's WSL-DistroLauncher reference implementation
// (github.com/microsoft/WSL-DistroLauncher, MIT). See LICENSE.
//

#pragma once

namespace DistributionInfo
{
    // The registered name of the distribution. Shown by `wsl -l`, used as the
    // install directory name, and displayed in Windows Terminal's dropdown.
    // Must match ^[a-zA-Z0-9._-]+$.
    //
    // WARNING: never change this between releases - users upgrading from an
    // older LarzOS.exe would otherwise get a second, broken registration.
    const std::wstring Name = L"LarzOS";

    // Console title bar while LarzOS is registering.
    const std::wstring WindowTitle = L"Installing LarzOS";

    // The rootfs ships this account at uid 1000 (see tools/build-rootfs.sh and
    // /etc/wsl-distribution.conf). The launcher just makes it the default; it
    // never prompts for a username.
    const std::wstring DefaultUser = L"larz";

    // Ensure DefaultUser exists (creating it only as a fallback for an older
    // rootfs that shipped without it), then return true.
    bool CreateUser(std::wstring_view userName);

    // Query the UID of the given account, or UID_INVALID.
    ULONG QueryUid(std::wstring_view userName);
}
