/*
    Autosplitter script for Magicland Dizzy ZX/CPC
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
    settings.Add("FirstRescue", true, "First Yokfolk Rescued", "Any%");
    settings.Add("SecondRescue", true, "Second Yokfolk Rescued", "Any%");
    settings.Add("ThirdRescue", true, "Third Yokfolk Rescued", "Any%");
    settings.Add("FourthRescue", true, "Fourth Yokfolk Rescued", "Any%");
    settings.Add("FifthRescue", true, "Fifth Yokfolk Rescued", "Any%");
    settings.Add("SixthRescue", true, "Sixth Yokfolk Rescued", "Any%");
    settings.Add("ZaksDeath", true, "Zaks' Death", "Any%");
    settings.Add("GameComplete", true, "Game Complete", "Any%");
}

update
{
    if (vars.ramBank2 == IntPtr.Zero)
    {
        vars.ramBank2 = vars.Lookup(game, new SigScanTarget(0, "30 01 1C CB 19 30 01 1D CB 19 30 02 C6 04 CB 19"), 8);
        if (vars.ramBank2 != IntPtr.Zero)
            print(String.Concat("RAM 2 Base found: 0x", vars.ramBank2.ToString("X")));
    }

    if (vars.ramBank2 != IntPtr.Zero)
    {
        if (vars.watchers == null)
        {
            vars.watchers = new MemoryWatcherList
            {
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x1D45)) { Name = "titleCheck" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x1D2A)) { Name = "diamondCount" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x1D42)) { Name = "yolkfolkInTrouble" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x1947)) { Name = "zaksDeath" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x1D23)) { Name = "roomId" }
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

    if (vars.watchers["titleCheck"].Old == 0 && vars.watchers["titleCheck"].Current == 255)
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

    if (vars.watchers["titleCheck"].Old == 255 && vars.watchers["titleCheck"].Current == 0)
    {
        print("Reset");
        return true;
    }
}

split
{
    if (vars.watchers as MemoryWatcherList == null
            || vars.watchers["diamondCount"] == null
            || vars.watchers["yolkfolkInTrouble"] == null
            || vars.watchers["zaksDeath"] == null
            || vars.watchers["roomId"] == null) return false;

    if (vars.watchers["yolkfolkInTrouble"].Old == 6 && vars.watchers["yolkfolkInTrouble"].Current == 5)
    {
        print("First yolkfolk rescued");
        return settings["FirstRescue"];
    }
    if (vars.watchers["yolkfolkInTrouble"].Old == 5 && vars.watchers["yolkfolkInTrouble"].Current == 4)
    {
        print("Second yolkfolk rescued");
        return settings["SecondRescue"];
    }
    if (vars.watchers["yolkfolkInTrouble"].Old == 4 && vars.watchers["yolkfolkInTrouble"].Current == 3)
    {
        print("Third yolkfolk rescued");
        return settings["ThirdRescue"];
    }
    if (vars.watchers["yolkfolkInTrouble"].Old == 3 && vars.watchers["yolkfolkInTrouble"].Current == 2)
    {
        print("Fourth yolkfolk rescued");
        return settings["FourthRescue"];
    }
    if (vars.watchers["yolkfolkInTrouble"].Old == 2 && vars.watchers["yolkfolkInTrouble"].Current == 1)
    {
        print("Fifth yolkfolk rescued");
        return settings["FifthRescue"];
    }
    if (vars.watchers["yolkfolkInTrouble"].Old == 1 && vars.watchers["yolkfolkInTrouble"].Current == 0)
    {
        print("Sixth yolkfolk rescued");
        return settings["SixthRescue"];
    }

    if (vars.watchers["roomId"].Current == 1 && vars.watchers["zaksDeath"].Old == 255 && vars.watchers["zaksDeath"].Current == 0)
    {
        print("Zaks death");
        return settings["ZaksDeath"];
    }

    if (vars.watchers["roomId"].Old == 112 && vars.watchers["roomId"].Current == 2)
    {
        print("Game complete");
        return settings["GameComplete"];
    }
}
