/*
    Autosplitter script for Treasure Island Dizzy ZX/CPC
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

startup
{
    // Enable or disable ALL splits
    settings.Add("splits", false, "Splits");

    // Categories
    settings.Add("Any%", true, "Any%", "splits");

    settings.Add("tinytim78", false, "tinytim78", "Any%");
    settings.Add("tinytim78_PickUpCamera", true, "Pick up a small video camera", "tinytim78");
    settings.Add("DropGoldenKey", true, "Drop a large golden key", "tinytim78");
    settings.Add("PickUpDinamite", true, "Pick up Dinamite", "tinytim78");
    settings.Add("tinytim78_GameComplete", true, "Game completed", "tinytim78");

    settings.Add("DigitalDuck", false, "DigitalDuck", "Any%");
    settings.Add("TenCoins", true, "Get 10 gold coins", "DigitalDuck");
    settings.Add("TwentyCoins", true, "Get 20 gold coins", "DigitalDuck");
    settings.Add("ThirtyCoins", true, "Get 30 gold coins", "DigitalDuck");
    settings.Add("DigitalDuck_GameComplete", true, "Game completed", "DigitalDuck");

    settings.Add("faddy91", false, "faddy91", "Any%");
    settings.Add("faddy91_PickUpCamera", true, "Pick up a small video camera", "faddy91");
    settings.Add("PickUpCursedTreasure", true, "Pick up the cursed treasure", "faddy91");
    settings.Add("PickUpMicrowave", true, "Pick up the microwave", "faddy91");
    settings.Add("PickUpGoldCoins", true, "Pick up the gold coins", "faddy91");
    settings.Add("faddy91_GameComplete", true, "Game completed", "faddy91");
}

init
{
    var mainModule = modules.First();
    print(String.Concat(game.ProcessName, ": 0x", mainModule.BaseAddress.ToString("X"), ", 0x", mainModule.ModuleMemorySize.ToString("X")));

    vars.ramBank0 = IntPtr.Zero;
    vars.ramBank5 = IntPtr.Zero;
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

update
{
    if (vars.ramBank0 == IntPtr.Zero)
    {
        vars.ramBank0 = vars.Lookup(game, new SigScanTarget(0, "64 22 88 47 64 2A 88 47 64 32 88 47 64 3A 88 47 64 42 88 47 64 4A 88 47 64 52 88 47 64 5A 88 47 FB 5A 98 8A 1C 52 88 12 FD 4F 8A 12 FB 4A A0 0A"), 8);
        if (vars.ramBank0 != IntPtr.Zero)
            print(String.Concat("RAM 0 Base found: 0x", vars.ramBank0.ToString("X")));
    }

    if (vars.ramBank5 == IntPtr.Zero)
    {
        vars.ramBank5 = vars.Lookup(game, new SigScanTarget(0, "00 00 3C 00 00 00 03 C3 83 8D CD C0 00 00 03 FE"), 8);
        if (vars.ramBank5 != IntPtr.Zero)
            print(String.Concat("RAM 5 Base found: 0x", vars.ramBank5.ToString("X")));
    }

    if (vars.ramBank0 != IntPtr.Zero && vars.ramBank5 != IntPtr.Zero)
    {
        if (vars.watchers == null)
        {
            vars.watchers = new MemoryWatcherList
            {
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank0 + 0x2FFA)) { Name = "coinCounter" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x1846)) { Name = "titleScreen" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x494)) { Name = "firstInventoryFirstValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x588)) { Name = "firstInventorySecondValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x594)) { Name = "firstInventoryThirdValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x454)) { Name = "lastInventoryFirstValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x548)) { Name = "lastInventorySecondValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x554)) { Name = "lastInventoryThirdValue" },
                new MemoryWatcher<byte>(new DeepPointer(vars.ramBank5 + 0x1E3)) { Name = "finalScroll" }
            };
        }
    }

    if (vars.watchers != null)
        vars.watchers.UpdateAll(game);
}


start
{
    if (vars.watchers == null || vars.watchers["titleScreen"] == null) return false;

    vars.pickedUpCamera = false;
    vars.droppedGoldenKey = false;
    vars.pickedUpCursedTreasure = false;
    vars.pickedUpMicrowave = false;
    vars.pickedUpDinamite = false;
    vars.pickedUpGoldCoins = false;

    if (vars.watchers["titleScreen"].Old == 71 && vars.watchers["titleScreen"].Current == 7)
    {
        Thread.Sleep(650);
        print("Start");
        return true;
    }
}

reset
{
    if (vars.watchers == null || vars.watchers["titleScreen"] == null) return false;

    if (vars.watchers["titleScreen"].Old == 7 && vars.watchers["titleScreen"].Current == 71)
    {
        print("Reset");
        return true;
    }
}

split
{
    if (vars.watchers == null
        || vars.watchers["coinCounter"] == null
        || vars.watchers["firstInventoryFirstValue"] == null
        || vars.watchers["firstInventorySecondValue"] == null
        || vars.watchers["firstInventoryThirdValue"] == null
        || vars.watchers["lastInventoryFirstValue"] == null
        || vars.watchers["lastInventorySecondValue"] == null
        || vars.watchers["lastInventoryThirdValue"] == null
        || vars.watchers["finalScroll"] == null) return false;

	if (timer.CurrentTime.RealTime < TimeSpan.FromSeconds(1))
	{
		return;
	}

    if (!vars.pickedUpCamera && 
        vars.watchers["firstInventoryFirstValue"].Current == 194 &&
        vars.watchers["firstInventorySecondValue"].Current == 198 &&
        vars.watchers["firstInventoryThirdValue"].Current == 238)
    {
        print("PickUpCamera");
        vars.pickedUpCamera = true;
        return (settings["tinytim78_PickUpCamera"] || settings["faddy91_PickUpCamera"]);
    }

    if (!vars.droppedGoldenKey && 
        vars.watchers["lastInventoryFirstValue"].Old == 206 && vars.watchers["lastInventorySecondValue"].Old == 0 && vars.watchers["lastInventoryThirdValue"].Old == 206 &&
        (vars.watchers["lastInventoryFirstValue"].Current != 206 || vars.watchers["lastInventoryThirdValue"].Current != 206))
    {
        print("DropGoldenKey");
        vars.droppedGoldenKey = true;
        return settings["DropGoldenKey"];
    }

    if (!vars.pickedUpCursedTreasure && 
        vars.watchers["firstInventoryFirstValue"].Current == 198 &&
        vars.watchers["firstInventorySecondValue"].Current == 230 &&
        vars.watchers["firstInventoryThirdValue"].Current == 230)
    {
        print("PickUpCursedTreasure");
        vars.pickedUpCursedTreasure = true;
        return settings["PickUpCursedTreasure"];
    }

    if (!vars.pickedUpMicrowave && 
        vars.watchers["firstInventoryFirstValue"].Current == 198 &&
        vars.watchers["firstInventorySecondValue"].Current == 230 &&
        vars.watchers["firstInventoryThirdValue"].Current == 238)
    {
        print("PickUpMicrowave");
        vars.pickedUpMicrowave = true;
        return settings["PickUpMicrowave"];
    }

    if (!vars.pickedUpDinamite && 
        vars.watchers["firstInventoryFirstValue"].Current == 198 &&
        vars.watchers["firstInventorySecondValue"].Current == 56 &&
        vars.watchers["firstInventoryThirdValue"].Current == 230)
    {
        print("PickUpDinamite");
        vars.pickedUpDinamite = true;
        return settings["PickUpDinamite"];
    }

    if (!vars.pickedUpGoldCoins && 
        vars.watchers["firstInventoryFirstValue"].Current == 194 &&
        vars.watchers["firstInventorySecondValue"].Current == 230 &&
        vars.watchers["firstInventoryThirdValue"].Current == 238)
    {
        print("PickUpGoldCoins");
        vars.pickedUpGoldCoins = true;
        return settings["PickUpGoldCoins"];
    }

    if (vars.watchers["coinCounter"].Old < 10 && vars.watchers["coinCounter"].Current == 10)
    {
        print("TenCoins");
        return settings["TenCoins"];
    }

    if (vars.watchers["coinCounter"].Old < 20 && vars.watchers["coinCounter"].Current == 20)
    {
        print("TwentyCoins");
        return settings["TwentyCoins"];
    }

    if (vars.watchers["coinCounter"].Old < 30 && vars.watchers["coinCounter"].Current == 30)
    {
        print("ThirtyCoins");
        return settings["ThirtyCoins"];
    }

    if (vars.watchers["coinCounter"].Current == 30 && vars.watchers["finalScroll"].Old == 0 && vars.watchers["finalScroll"].Current == 170)
    {
        print("GameComplete");
        return (settings["tinytim78_GameComplete"] || settings["DigitalDuck_GameComplete"] || settings["faddy91_GameComplete"]);
    }


}