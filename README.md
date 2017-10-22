# Charge Transmission

Special Factorio beacon-like entities that wirelessly charge bots around them. An idea by Mike C from the KatherineOfSkies community.

Bots waste a lot of time (and power bursts) having to recharge in the middle of their activities. But if you've got module effect transmission already, how hard would it be to beam electricity around as well...?

Enter the **Bot Charger**, the only entity added by this mod, which works exactly as it says on the tin.

## Recipe

- 1x **beacon**
- 2x **radars**
- 10x **processing units**
- 20x **batteries**

## How to use

1. Research Charge Transmission;
1. Place **Bot Charger** near the desired roboport;
   - Reassign the target, if necessary, by selecting its antenna and rotating it (pressing R);
1. You're done.

From now on, the charger will scan over that roboport's *construction range* and recharge any bots inside it every second or so.

Chargers connected to the same roboport will share the load between themselves; this is important as each charger has a limited energy input amount and can only fulfil so many robots (see overtaxing below).

### Reassigning a target roboport

Chargers will try to pair up with the closest roboport by default, preferring roboports that are already connected to other chargers. *You can see what roboport a charger's servicing by selecting the charger's antenna*, a giant arrow will appear pointing at the roboport while you do so.

![roboport with picker arrow because of highlighted antenna](https://media.giphy.com/media/l0IymrhGnuE4MhTd6/giphy.gif)

To change the target roboport, rotate the charger's antenna with R until the arrow points at your preferred spot. A roboport will only be a possible target if it has the charger as its neighbour (in other words, if it is inside its logistic range).

## Power usage

To know why a charger is requiring that much power, you first must know how much a robot truly costs to run. A robot's power usage is calculated as follows:

```math
E(bot) = drain + speed * movement cost * worker speed bonus
```

- *Drain* and *movement cost* can be gathered from a robot's tooltip, they're the `3kW + 5kJ/m`, respectively.
- *Worker speed bonus* can be found from the Bonuses tab (warning: `+300%` would mean the total is `400%`).
- *Speed* isn't directly said in-game but for vanilla it's `3m/s` for logistic robots and `3.6m/s` for construction robots.

This means that the more *Worker Robot Speed* research obtained the higher a bot's energy maintenance will be, and that construction robots are always slightly more power hungry.

**Chargers only work at 66.7% efficiency**, that is, they take 1.5x the necessary power to charge robots. By default, a single charger can handle up to 750 active construction robots, but at max robot speed (before infinite science), that drops to about 250.

If that sounds low, don't worry: because robots go faster, from the speed research, and don't need to stop to charge, your robotic demands will be smaller with chargers around.

## Overtaxing

A charger will display a custom alert over itself when it is **overtaxed**. It's hard to miss as it blinks like any other in-game alert.

![charged overtaxed, showing an alert](https://media.giphy.com/media/3o7aCWPMdzNUu8vTsk/giphy.gif)

This means that the charger's power needs are bigger than what it can take from the network. Now, this may mean two possibilities: either your power supply isn't sufficient or, most likely than not, there's just too many robots for that single charger to handle at once, as they have a max recharge rate of 24MW. For contrast, a vanilla roboport has a 5MW max recharge rate.

An overtaxed charger will slowly deplete its considerable energy buffers, always charging as many robots as it can. This means that it will, at first, work without issues but eventually not be able to charge everything, which then ends up on some, if not all, robots having to use the traditional charging methods, as shown on the image above.

Easy solution though: *chargers that point to the same roboport will share their work load*, so just add more chargers! It can also pay to wait, as it takes a while for robots to be topped off initially, as when you just placed the charger or if a swarm of new bots just came from somewhere else. Still, if you see the alert, it won't hurt to construct additional chargers.

~~Maybe I should have called them energy pylons instead.~~

## FAQ

### My charger doesn't seem to be doing anything

Well, chargers don't have any particle effects, by design (lag, ya know) to warn they've charged a bot. But they do have a visual way to show they're working: the antenna only spins when it's charging bots (or topping its internal energy buffer).

If you're sure a charger is out of commission (bots still charging around the roboport rather frequently), the likely reasons are:

1. Charger isn't paired to any roboport
1. Charger is overtaxed (orange alert)
1. Energy supply isn't enough to keep the charger powered up

For the first one, hover your mouse over the charger's antenna and see if it points to any roboport. If not, pick and place the charger on a more suitable (closer) place.

The second and third issues are usually telegraphed in-game by alerts. To verify this, check the electricity values on the sidebar, both the main body (base) AND the antenna must be on the green to be functioning properly. If not, try increasing the power supply or adding more chargers.

### How does LuaForce::worker\_robots\_battery\_modifier affect chargers

In short, it does not! It only changes the maximum charge a bot can have, with average/over time consumption staying the same. Usually what happens is bigger use spikes, if any, but the same consumption under regular circumstances stays the same on a factory faction with or without the modifier. And the modifier is really useful to alleviate charging headaches to start with...

### I found a bug! Please fix it

Sure! But I'll need a bug report for it. Describing what you were doing (+ steps to replicate the issue), what other mods you have installed, what version of this mod you have and if possible, sending me your bugged save-game. All these steps will make your issue much easier to diagnose and to be fixed.

***DO NOT post your bug report here on the mod portal***, as it doesn't notify the mod maintainers about new posts or replies so it may take literal weeks for stuff to be noticed. Please, *please*, use the [forum thread](https://forums.factorio.com/viewtopic.php?f=97&t=49853) or [github repo](https://github.com/dustine/ChargeTransmission/issues) to make your bug report.

## Credits

Special thanks to:

- Mike C for the concept and not giving up on it
- Xterminator for the video spotlight of v0.4
- [KatherineOfSkies](https://www.youtube.com/channel/UCTIV3KbAvaGEyNjoMoNaGtQ/) for her friendly and welcoming community
- desseb for being key on the brainstorming and play-testing
- Nexela for general code help and workarounds
- eradicator for crucial help with ups optimizations

This mod contains graphics adapted from the icons made by [Roundicons](http://www.flaticon.com/authors/roundicons) and [Gregor Cresnar](http://www.flaticon.com/authors/gregor-cresnar) from [www.flaticon.com](http://www.flaticon.com) under a [CC 3.0 BY](http://creativecommons.org/licenses/by/3.0/) license.