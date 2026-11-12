// ============================================================
//  stdin_ready.cpp — does stdin have input waiting, without blocking?
//
//  sim_main.cpp checks this between evaluations while the simulation
//  runs, to pick up the bridge's commands. POSIX: poll(). Windows (MSYS2
//  builds): no poll() on pipes, so PeekNamedPipe for the bridge's pipe,
//  and the console's input-event count when typed into by hand. Kept in
//  its own file so <windows.h> stays out of the model's code.
// ============================================================
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

bool liveStdinReady() {
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    switch (GetFileType(h)) {
    case FILE_TYPE_PIPE: {
        DWORD avail = 0;
        // A closed pipe fails here: report it ready, so getline sees the EOF
        if (!PeekNamedPipe(h, nullptr, 0, nullptr, &avail, nullptr)) return true;
        return avail > 0;
    }
    case FILE_TYPE_CHAR: {
        DWORD n = 0;
        return GetNumberOfConsoleInputEvents(h, &n) && n > 0;
    }
    default:
        return true;   // a file: always readable
    }
}
#else
#include <poll.h>

bool liveStdinReady() {
    pollfd p{0, POLLIN, 0};
    return poll(&p, 1, 0) > 0 && (p.revents & (POLLIN | POLLHUP));
}
#endif
