state("W2") {}

init {
    vars.NUM_MISSIONS = 45;
    vars.baseAddr = (uint)modules.First().BaseAddress;

    current.selectedTeamIndex = -1;
    current.missionMedals = new byte[vars.NUM_MISSIONS];
}

update {
    current.selectedTeamIndex = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x70d143));
    if (current.selectedTeamIndex != old.selectedTeamIndex) {
        print("selected team change: " + current.selectedTeamIndex);
    }

    current.missionMedals = new byte[vars.NUM_MISSIONS];
    for (int i = 0; i < vars.NUM_MISSIONS; i++) {
        current.missionMedals[i] = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x725c5c + current.selectedTeamIndex * 4060 + 8 * i));
        //print("mission: " + i + " is: " + current.missionMedals[i]);
    }
}

split {
    if (current.selectedTeamIndex != old.selectedTeamIndex)
        return false;

    for (int i = 0; i < vars.NUM_MISSIONS; i++) {
        if (old.missionMedals[i] == 0 && current.missionMedals[i] != 0) {
            print("passed mission: " + i);
            return true;
        }
    }

    return false;
}

start {
    var topmostWindow = memory.ReadValue<uint>(new IntPtr(vars.baseAddr + 0x745000));
    if (topmostWindow != 0x0) {
        // Start timer if vtable of window object points to one for the
        // "Please wait... Working..." dialog.
        var vtable = memory.ReadValue<uint>(new IntPtr(topmostWindow));
        return vtable == vars.baseAddr + 0x46f02c;
    }
    return false;
}
