LanguageNames = (English=0x409:MSG00409)

MessageId=1001 SymbolicName=MSG_WSL_REGISTER_DISTRIBUTION_FAILED
Language=English
Registering LarzOS failed with error: 0x%1!x!
.

MessageId=1002 SymbolicName=MSG_WSL_CONFIGURE_DISTRIBUTION_FAILED
Language=English
Configuring LarzOS failed with error: 0x%1!x!
.

MessageId=1003 SymbolicName=MSG_WSL_LAUNCH_INTERACTIVE_FAILED
Language=English
Running %1 in LarzOS failed with error: 0x%2!x!
.

MessageId=1004 SymbolicName=MSG_WSL_LAUNCH_FAILED
Language=English
Launching %1 in LarzOS failed with error: 0x%2!x!
.

MessageId=1005 SymbolicName=MSG_USAGE
Language=English
LarzOS - a Debian-based Linux where Larzscript runs the machine, in WSL.

Usage:
    <no args>
        Install LarzOS if needed, then open a LarzOS shell.

    install [--root]
        Install LarzOS and exit without opening a shell.
          --root
              Do not set a default user; leave the default user as root.

    run <command line>
        Run the given command inside LarzOS in the current directory.

    config --default-user <username>
        Set the default user for LarzOS. The user must already exist.

    help
        Print this message.

More: https://larzos.com/larzos-linux/
.

MessageId=1006 SymbolicName=MSG_STATUS_INSTALLING
Language=English
Installing LarzOS, this may take a few minutes...
.

MessageId=1007 SymbolicName=MSG_INSTALL_SUCCESS
Language=English
LarzOS is installed. Launch it from the Start menu, Windows Terminal, or `wsl -d LarzOS`.
.

MessageId=1008 SymbolicName=MSG_ERROR_CODE
Language=English
Error: 0x%1!x! %2
.

MessageId=1009 SymbolicName=MSG_ENTER_USERNAME
Language=English
Enter new UNIX username: %0
.

MessageId=1010 SymbolicName=MSG_CREATE_USER_PROMPT
Language=English
Creating the default LarzOS user...
.

MessageId=1011 SymbolicName=MSG_PRESS_A_KEY
Language=English
Press any key to continue...
.

MessageId=1013 SymbolicName=MSG_INSTALL_ALREADY_EXISTS
Language=English
The LarzOS installation looks corrupted.
Reset it from the app settings, or uninstall and reinstall LarzOS.
.

MessageId=1014 SymbolicName=MSG_ENABLE_VIRTUALIZATION
Language=English
Enable the "Virtual Machine Platform" Windows feature and turn on virtualization
in your BIOS, then try again. Guide: https://larzos.com/larzos-linux/
.

MessageId=1015 SymbolicName=MSG_MISSING_WSL_COMPONENT
Language=English
LarzOS needs the Windows Linux engine, which is off on this PC.

Open PowerShell as Administrator and run:

    wsl --install --no-distribution

then reboot and start LarzOS again. (This is a one-time Windows setup; you won't
need to touch it after that.)
.
