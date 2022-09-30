state("W2") {}

init {
    vars.baseAddr = (uint)modules.First().BaseAddress;

    current.topmostWindowVtable = 0x0u;
}

update {
    var topmostWindow = memory.ReadValue<uint>(new IntPtr(vars.baseAddr + 0x745000));
    if (topmostWindow != 0x0) {
        current.topmostWindowVtable = memory.ReadValue<uint>(new IntPtr(topmostWindow));
    } else {
        current.topmostWindowVtable = 0x0u;
    }
}

split {
    // Split if vtable of topmost window object points to the mission success dialog.
    if (current.topmostWindowVtable != old.topmostWindowVtable && current.topmostWindowVtable == vars.baseAddr + 0x4685bc) {
        return true;
    }

    return false;
}

start {
    // Start timer if vtable of topmost window object points to one for the
    // "Please wait... Working..." dialog.
    return current.topmostWindowVtable == vars.baseAddr + 0x46f02c;
}
