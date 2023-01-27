state("WA") {}

startup {
    settings.Add("basicTrainingSubsplits", false, "Basic Training subsplits");
}

init {
    vars.NUM_TRAININGS = 6;
    vars.NUM_MISSIONS = 33;
    vars.baseAddr = (uint)modules.First().BaseAddress;
    vars.skipNextSplitHack = false;

    current.inMainGame = 0;
    current.deathmatchWins = 0;
    current.selectedTeamIndex = -1;
    current.trainingMedals = new byte[vars.NUM_TRAININGS];
    current.missionMedals = new byte[vars.NUM_MISSIONS];
    current.isOnPopupWindow = false;
    current.isOnPleaseWaitWindow = false;
    current.isOnSingleplayerWindow = false;
}

update {
    current.inMainGame = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x3c0a20));

    // Index of the team selected for doing missions/trainings in GUI (0 == no team)
    // First locate training medals array (see below) then find xref like:
    // movsx   ecx, byte_137811F
    // imul    ecx, 0F10h
    // movsx   eax, byte_138F3C4[ecx]
    current.selectedTeamIndex = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x047811f));

    // TODO document this address
    current.deathmatchWins = memory.ReadValue<byte>(new IntPtr(vars.baseAddr + 0x48ecd8 + current.selectedTeamIndex * 3856));

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
        current.isOnPleaseWaitWindow = vtable == vars.baseAddr + 0x25f040;
        current.isOnSingleplayerWindow = vtable == vars.baseAddr + 0x2603b0;
    }
}

split {
    // Quick game was launched
    if (current.isOnPleaseWaitWindow && old.isOnSingleplayerWindow)
        return true;

    if (current.selectedTeamIndex != old.selectedTeamIndex)
        return false;

    if (current.deathmatchWins > old.deathmatchWins)
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

    // If 'Basic Training subsplits' set, then split at start of each round.
    // (Except the very first one of course)
    if (settings["basicTrainingSubsplits"] &&
            current.trainingMedals[0] < 3 &&
            current.deathmatchWins == 0 &&
            current.inMainGame == 1 && old.inMainGame == 0) {
        if (vars.skipNextSplitHack) {
            vars.skipNextSplitHack = false;
            return false;
        }
        return true;
    }

    return false;
}

start {
    // Quick game was launched
    if (current.isOnPleaseWaitWindow && old.isOnSingleplayerWindow)
        return true;

    if (current.selectedTeamIndex != old.selectedTeamIndex)
        return false;

    // Deathmatch was launched
    if (current.inMainGame == 1 && old.inMainGame == 0)
        return true;

    // Basic training was launched
    if (current.isOnPopupWindow && !old.isOnPopupWindow) {
        if (settings["basicTrainingSubsplits"]) {
            vars.skipNextSplitHack = true;
        }
        return true;
    }

    return false;
}
