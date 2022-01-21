/*
    Autosplitter script for Dizzy - The Ultimate Cartoon Adventure ZX/CPC
    Script version 1.0b1
    Theoretically works with any emulator but tested with
    Fuse 1.6.0
    SpecEmu 3.1.b170921, 3.2.b271021
    Spud 0.252
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
    settings.Add("AllEggs", false, "All Eggs", "splits");

    // Enable or disable individual splits
    settings.Add("BirdseedDrop", true, "Drop birdseed for the first time", "Any%");
    settings.Add("FirstIngredient", true, "Add first ingredient", "Any%");
    settings.Add("SecondIngredient", true, "Add second ingredient", "Any%");
    settings.Add("ThirdIngredient", true, "Add third ingredient", "Any%");
    settings.Add("FourthIngredient", true, "Add fourth ingredient", "Any%");
    settings.Add("GameComplete", true, "Game completed", "Any%");

    settings.Add("EggGet", true, "Picked up an egg", "AllEggs");
    settings.Add("GameCompleteAllEggs", true, "Game completed", "AllEggs");
}

update
{
    if (vars.ramBank0 == IntPtr.Zero)
    {
        vars.ramBank0 = vars.Lookup(game, new SigScanTarget(0, "00 00 3C 00 00 00 00 F0"), 8);
        if (vars.ramBank0 != IntPtr.Zero)
            print(String.Concat("RAM 0 Base found: 0x", vars.ramBank0.ToString("X")));
    }

    if (vars.ramBank2 == IntPtr.Zero)
    {
        vars.ramBank2 = vars.Lookup(game, new SigScanTarget(0, "68 06 20 00 00 00 3C 00"), 8);
        if (vars.ramBank2 != IntPtr.Zero)
            print(String.Concat("RAM 2 Base found: 0x", vars.ramBank2.ToString("X")));
    }

    if (vars.ramBank0 != IntPtr.Zero && vars.ramBank2 != IntPtr.Zero)
    {
        if (vars.watchers == null)
        {
            vars.watchers = new MemoryWatcherList
            {
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x1AA)) { Name = "titleCheck" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x169)) { Name = "inventoryValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x34EC)) { Name = "lifeCounter" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x148D)) { Name = "totalIngredients" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank2 + 0x3A52)) { Name = "gameCompleteCheck"}
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

    if (vars.watchers["titleCheck"].Old == 30 && vars.watchers["titleCheck"].Current == 0)
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

    if (vars.watchers["titleCheck"].Old == 0 && vars.watchers["titleCheck"].Current == 30)
    {
        print("Reset");
        return true;
    }
}

split
{
    if (vars.watchers == null 
        || vars.watchers["titleCheck"] == null
        || vars.watchers["inventoryValue"] == null
        || vars.watchers["totalIngredients"] == null
        || vars.watchers["gameCompleteCheck"] == null
        || vars.watchers["lifeCounter"] == null) return false;


    // If you quit or die while holding the birdseed, it will detect as dropped when you start the game triggering a false split.
    // We can prevent this by ignoring splits for a second
	if (timer.CurrentTime.RealTime < TimeSpan.FromSeconds(1))
	{
		return;
	}

    // Check if bird seed has dropped.  Quite a few values change on item pick up / drop so this check was built via testing and experimentation
    if (!vars.birdseedDropped && vars.watchers["inventoryValue"].Old == 63 && vars.watchers["inventoryValue"].Current == 0)
    {
        vars.birdseedDropped = true;
        print("Birdseed Dropped");
        return settings["BirdseedDrop"];
    }

    // Check for ingredients being added to the cauldron
    if (vars.watchers["totalIngredients"].Old == 0 && vars.watchers["totalIngredients"].Current == 1)
    {
        print("First Ingredient");
        return settings["FirstIngredient"];
    }
    if (vars.watchers["totalIngredients"].Old == 1 && vars.watchers["totalIngredients"].Current == 2)
    {
        print("Second Ingredient");
        return settings["SecondIngredient"];
    }
    if (vars.watchers["totalIngredients"].Old == 2 && vars.watchers["totalIngredients"].Current == 3)
    {
        print("Third Ingredient");
        return settings["ThirdIngredient"];
    }
    if (vars.watchers["totalIngredients"].Old == 3 && vars.watchers["totalIngredients"].Current == 4)
    {
        print("Fourth Ingredient");
        return settings["FourthIngredient"];
    }

    // This value was also built via testing and trialling.  It should only fire at the moment the game completes
    if (vars.watchers["gameCompleteCheck"].Old == 2 && vars.watchers["gameCompleteCheck"].Current == 4)
    {
        print("Game Completed");
        return (settings["GameComplete"] || settings["GameCompleteAllEggs"]);
    }

    // Check for life counter increments - indicates egg pickup.
    // Need to filter 255 as this value is set upon dying to title
    if (vars.watchers["lifeCounter"].Old < vars.watchers["lifeCounter"].Current && vars.watchers["lifeCounter"].Current != 255)
    {
        print("Egg Collected");
        return settings["EggGet"];
    }

}