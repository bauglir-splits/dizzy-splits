/*
    Autosplitter script for Fantasy World Dizzy ZX/CPC
    Script version 1.0b1
    Theoretically works with any emulator but tested with
    Fuse 1.6.0
    BizHawk 2.70
*/

state("EmuHawk") { }
state("fuse") { }
state("SpecEmu") { }
state("Spud") { }
state("Spectaculator") { }
state("ZXSpectrum4") { }

init
{
    var mainModule = modules.First();
    print(String.Concat(game.ProcessName, ": 0x", mainModule.BaseAddress.ToString("X"), ", 0x", mainModule.ModuleMemorySize.ToString("X")));

    vars.ramBank0 = IntPtr.Zero;
    vars.ramBank2 = IntPtr.Zero;
    vars.watchers = null;

    vars.Lookup = (Func<Process, SigScanTarget, int, IntPtr>)((proc, target, align) =>
    {
        IntPtr result = IntPtr.Zero;
        var scanner = new SignatureScanner(proc, mainModule.BaseAddress, mainModule.ModuleMemorySize);
        if ((result = scanner.Scan(target, align)) != IntPtr.Zero)
            return result;
        foreach(var page in proc.MemoryPages())
        {
            scanner = new SignatureScanner(proc, page.BaseAddress, (int)page.RegionSize);
            if ((result = scanner.Scan(target, align)) != IntPtr.Zero)
                return result;
        }
        return result;
    });
}

startup
{
    // Enable or disable ALL splits
    settings.Add("splits", false, "Splits");

    // Categories
    settings.Add("Any%", false, "Any%", "splits");

    // Enable or disable individual splits
    settings.Add("BottomLeftKey", true, "Bottom Left Key", "Any%");
    settings.Add("PullLever", true, "Pull Lever", "Any%");
    settings.Add("BoulderBridge", true, "2 Boulders 1 Bridge", "Any%");
    settings.Add("OpenUpTheWell", true, "Open Up the Well", "Any%");
    settings.Add("WaterTheMagicPile", true, "Water the Magic Pile", "Any%");
    settings.Add("BreakTheRock", true, "Break the Rock", "Any%");
    settings.Add("ThrowTheRug", true, "Throw the Rug", "Any%");
    settings.Add("MeetDaisy", true, "Meet Daisy (Game Complete)", "Any%");
}

update
{
    if (vars.ramBank0 == IntPtr.Zero)
    {
        vars.ramBank0 = vars.Lookup(game, new SigScanTarget(0, "04 FB 04 2D 05 4F 05 32 11 8E 02 B0 02 C2 02 E2"), 8);
        if (vars.ramBank0 != IntPtr.Zero)
            print(String.Concat("RAM 0 Base found: 0x", vars.ramBank0.ToString("X")));
    }

    if (vars.ramBank2 == IntPtr.Zero)
    {
        vars.ramBank2 = vars.Lookup(game, new SigScanTarget(0, "C4 40 E4 CC 40 E8 D4 39 E8 B4 51 E6 D0 36 E6 C8"), 8);
        if (vars.ramBank2 != IntPtr.Zero)
            print(String.Concat("RAM 2 Base found: 0x", vars.ramBank2.ToString("X")));
    }

    if (vars.ramBank0 != IntPtr.Zero && vars.ramBank2 != IntPtr.Zero)
    {
        if (vars.watchers == null)
        {
            vars.watchers = new MemoryWatcherList
            {
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x3925)) { Name = "titleCheck" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x392D)) { Name = "coinCounter" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x394B)) { Name = "meetDaisy" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x29DE)) { Name = "bottomLeftKey" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x283E)) { Name = "pullLever" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x2E8D)) { Name = "boulderBridge" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x2B47)) { Name = "openUpTheWell" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x287E)) { Name = "waterTheMagicPile" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x2B74)) { Name = "breakTheRock" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x2BC4)) { Name = "throwTheRug" }
            };
        }
    }

    if (vars.watchers != null)
        vars.watchers.UpdateAll(game);
}

start
{
    if (vars.watchers == null || vars.watchers["titleCheck"] == null) return false;
    // Flag set when birdseed is dropped
    vars.birdseedDropped = false;

    if (vars.watchers["titleCheck"].Old == 0 && vars.watchers["titleCheck"].Current != 0)
    {
        print("Start");
        return true;
    }
}

reset
{
    // This will reset any time you drop to the title screen.
    // There may be an undesirable corner case here if you finish a run without also finishing your splits.
    // If this is a concern it may be better to disable auto resets.

    if (vars.watchers == null || vars.watchers["titleCheck"] == null) return false;

    if (vars.watchers["titleCheck"].Old != 0 && vars.watchers["titleCheck"].Current == 0)
    {
        print("Reset");
        return true;
    }
}

split
{
    if (vars.watchers as MemoryWatcherList == null
            || vars.watchers["bottomLeftKey"] == null
            || vars.watchers["pullLever"] == null
            || vars.watchers["boulderBridge"] == null
            || vars.watchers["openUpTheWell"] == null
            || vars.watchers["waterTheMagicPile"] == null
            || vars.watchers["breakTheRock"] == null
            || vars.watchers["throwTheRug"] == null
            || vars.watchers["meetDaisy"] == null) return false;
    
    if (vars.watchers["bottomLeftKey"].Old == 0 && vars.watchers["bottomLeftKey"].Current == 1)
    {
        print("Bottom Left Key");
        return settings["BottomLeftKey"];
    }

    if (vars.watchers["pullLever"].Old == 0 && vars.watchers["pullLever"].Current == 1)
    {
        print("Pull Lever");
        return settings["PullLever"];
    }

    if (vars.watchers["boulderBridge"].Old == 6 && vars.watchers["boulderBridge"].Current == 12)
    {
        print("2 Boulders 1 Bridge");
        return settings["BoulderBridge"];
    }
    
    if (vars.watchers["openUpTheWell"].Old == 160 && vars.watchers["openUpTheWell"].Current == 144)
    {
        print("Open up the Well");
        return settings["OpenUpTheWell"];
    }
    
    if (vars.watchers["waterTheMagicPile"].Old == 1 && vars.watchers["waterTheMagicPile"].Current == 2)
    {
        print("Water the Magic Pile");
        return settings["WaterTheMagicPile"];
    }
    
    if (vars.watchers["breakTheRock"].Old == 41 && vars.watchers["breakTheRock"].Current == 11)
    {
        print("Break the Rock");
        return settings["BreakTheRock"];
    }
    
    if (vars.watchers["throwTheRug"].Old == 255 && vars.watchers["throwTheRug"].Current == 94)
    {
        print("Throw the Rug");
        return settings["ThrowTheRug"];
    }
    
    if (vars.watchers["meetDaisy"].Old == 0 && vars.watchers["meetDaisy"].Current == 1)
    {
        print("Meet Daisy (Game Complete)");
        return settings["MeetDaisy"];
    }
    
}
