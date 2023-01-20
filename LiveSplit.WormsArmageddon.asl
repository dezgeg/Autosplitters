state("WA") {}

startup {
    settings.Add("basicTrainingSubsplits", false, "Basic Training subsplits");
}

init {
    vars.NUM_TRAININGS = 6;
    vars.NUM_MISSIONS = 33;
    vars.baseAddr = (uint)modules.First().BaseAddress;

    current.inMainGame = 0;
    current.maxDeathmatchRank = 0;
    current.selectedTeamIndex = -1;
    current.trainingMedals = new byte[vars.NUM_TRAININGS];
    current.missionMedals = new byte[vars.NUM_MISSIONS];
    current.isOnPopupWindow = false;
}

update {
    current.inMainGame = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x3c0a20));

    // Index of the team selected for doing missions/trainings in GUI (0 == no team)
    // First locate training medals array (see below) then find xref like:
    // movsx   ecx, byte_137811F
    // imul    ecx, 0F10h
    // movsx   eax, byte_138F3C4[ecx]
    current.selectedTeamIndex = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x047811f));

    var deathmatchRank = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x48f382 + current.selectedTeamIndex * 3856)) / 2;
    if (current.selectedTeamIndex != old.selectedTeamIndex) {
        print("selected team change: " + current.selectedTeamIndex);
        current.maxDeathmatchRank = deathmatchRank;
    } else {
        // Value in memory is times 2
        // As rank can go down if we lose, take Max()
        current.maxDeathmatchRank = Math.Max(current.maxDeathmatchRank, deathmatchRank);
    }

    // Xref search for: aGraphicsTeamin_1 db 'Graphics\TeamInfo\MissionBronze.bmp',0
    // Before it, training medals array access looks like:
    // imul    ecx, 3856
    // movsx   eax, byte_138F3C4[ecx+ebx]
    // Before it, mission medals array access looks like:
    // imul    ecx, 482
    // add     ecx, ebp
    // mov     eax, dword_138ED08[ecx*8]
    current.trainingMedals = new byte[vars.NUM_TRAININGS];
    for (int i = 0; i < vars.NUM_TRAININGS; i++) {
        current.trainingMedals[i] = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x48f3c4 + current.selectedTeamIndex * 3856 + i));
        //print("training: " + i + " is: " + current.trainingMedals[i]);
    }

    current.missionMedals = new byte[vars.NUM_MISSIONS];
    for (int i = 0; i < vars.NUM_MISSIONS; i++) {
        current.missionMedals[i] = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x48ed08 + current.selectedTeamIndex * 3856 + 8 * i));
        //print("mission: " + i + " is: " + current.missionMedals[i]);
    }

    // Pointer to topmost GUI window. To locate:
    // xref search for LockWindowUpdate, pick function which has this in beginning:
    // call    ds:ReleaseCapture
    // mov     eax, dword_12a03dc
    // mov     ecx, [edi+60h]
    // mov     esi, [edi+5Ch]
    // mov     [edi+124h], eax
    // mov     dword_12a03dc, edi
    //         ^^^^^^^^^^^^^
    var topmostWindow = memory.ReadValue<uint>(new IntPtr(vars.baseAddr + 0x3a03dc));
    if (topmostWindow != 0x0) {
        var vtable = memory.ReadValue<uint>(new IntPtr(topmostWindow));
        // Start timer if vtable of window object points to one for dialog box
        // (in other words, on popup showing 1st basic training instructions)
        current.isOnPopupWindow = vtable == vars.baseAddr + 0x2585a8;
    }
}

split {
    if (current.selectedTeamIndex != old.selectedTeamIndex)
        return false;

    if (current.maxDeathmatchRank > old.maxDeathmatchRank)
        return true;

    for (int i = 0; i < vars.NUM_TRAININGS; i++) {
        if (old.trainingMedals[i] != 3 && current.trainingMedals[i] == 3) {
            //print("golded in training: " + i);
            return true;
        }
    }

    for (int i = 0; i < vars.NUM_MISSIONS; i++) {
        if (old.missionMedals[i] == 0 && current.missionMedals[i] != 0) {
            //print("passed mission: " + i);
            return true;
        }
    }

    if (settings["basicTrainingSubsplits"] && current.trainingMedals[0] < 3 && current.maxDeathmatchRank == 0) {
        return current.isOnPopupWindow && !old.isOnPopupWindow;
    }

    return false;
}

start {
    if (current.selectedTeamIndex != old.selectedTeamIndex)
        return false;

    if (current.inMainGame == 1 && old.inMainGame == 0)
        return true;

    return current.isOnPopupWindow && !old.isOnPopupWindow;
}
