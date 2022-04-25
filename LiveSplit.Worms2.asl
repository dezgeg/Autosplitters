state("frontend") {
    // 0-based mission number.
    uint mission : "frontend.exe", 0x1b5368;
}

init {
    var exePath = modules.First().FileName;
    vars.datPath = Path.GetDirectoryName(exePath) + "/Data/game.dat";

    vars.prevPhase = null;
    vars.prevMtime = null;
}

update {
    if (timer.CurrentPhase != vars.prevPhase) {
        if (timer.CurrentPhase == TimerPhase.NotRunning) {
            vars.prevMtime = File.GetLastWriteTime(vars.datPath);
        }
    }
    vars.prevPhase = timer.CurrentPhase;
}

split {
    // Don't split when going from 1st mission to any other mission than 2nd. That way, accidentally
    // exiting to main menu and using a password to go back to correct mission doesn't split.
    // (Except, using password to go to 2nd mission still causes an extra split :D)
    return current.mission > old.mission && (old.mission > 0 || current.mission == 1);
}

start {
    // Right before frontend starts the main game, it writes to game.dat the details of the game.
    // So timer starts at same time as the main game (even if it's not a mission game...).
    return vars.prevMtime != File.GetLastWriteTime(vars.datPath);
}
