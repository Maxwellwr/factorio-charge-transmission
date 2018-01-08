# Charge Transmission

Special Factorio beacon-like entities that wirelessly charge bots around them. An idea by Mike C from the KatherineOfSkies community.

Bots waste a lot of time and energy having to recharge in the middle of their activities. But if you've got module effect transmission already, how hard would it be to beam electricity around as well...?

Enter the **Bot Charger**, the only entity added by this mod (for now!), which works exactly as it says on the tin.

![bot charger](https://i.imgur.com/8xiVnL3.png)

(If you're one for a visual demonstration, [Xterminator did a mod spotlight video on Charge Transmission v0.5](https://youtu.be/Wagxa-6FbVY). Thank you so much!)

## Recipe

- 1x **beacon**
- 2x **radars**
- 10x **processing units**
- 20x **batteries**

## How to use

1. Research Charge Transmission;
1. Place a **Bot Charger** near the desired roboport;
   - Reassign the target, if necessary, by selecting its arrowed display and rotating it (pressing R);

From now on, the charger will listen on any robots wishing to recharge themselves and top them off before they move towards the roboport, saving time and resources at the expense of some extra energy.

You know it's working when you see sparks flying off the roboport at the hapless robot (can be toggled off).

![very busy roboport with wireless charging beams](https://i.imgur.com/Nr8ScW2.png)

(If it looks weird, that's because the energy blasts are aimed at a robot's shadow.)

Chargers connected to the same roboport will share the load between themselves; this is important as each charger has a limited energy input amount and can only fulfil so many robots (see Overtaxing below).

### Reassigning a target roboport

Chargers will try to pair up with the closest roboport by default, preferring roboports that are already connected to other chargers. You can see what roboport a charger's servicing by the direction its arrowed display shows (or none if the charger is unpaired), and hovering your mouse over it will display a giant arrow pointing at the target roboport.

![roboport with picker arrow because of highlighted antenna](https://media.giphy.com/media/3ohc1fMBRzLjuGdTa0/giphy.gif)

To change the target roboport, rotate the display with R until the arrow points at your preferred spot. A roboport will only be a possible target if it is inside its logistic range.

### Using modules

As the unlocking technology for them hints, chargers are retrofitted beacons for electricity. And with how power hungry chargers can be (see Power usage), it would make sense that you'd be able to improve this somehow.

![charger bio, showing their modules](https://i.imgur.com/InCz8vV.png)

Chargers have the same distribution efficiency than the basegame beacons, halving their possible effect.  *Chargers also have no coverage area*, as shown, so its beaconed effect (that can only be energy efficiency) only applies to that specific charger and its assigned roboport for wireless charging purposes. Also, **charger performance can't be affected by other chargers or beacons**, selfish as they are.

You can also disable this feature on the mod settings, but the mod is balanced around the usage of modules.

## Overtaxing

A targeted roboport will display a custom alert over itself when it is **overtaxed**. It's hard to miss as it blinks like any other in-game alert. That and it's usually surrounded by robots being recharged by said roboport.

![roboport overtaxed surrounded by charging robots, showing an alert](https://media.giphy.com/media/l49JBr82bF2OcAFwY/giphy.gif)

It also shows up as a custom alert for players and on one's map.

![map mode preview with alert box and tooltip](https://i.imgur.com/NrbMosT.png)

This means that the chargers can't cope with recharging all their target robots. Now, either your power supply isn't sufficient or, most likely than not, there's just too many robots as each charger can only supply so many robots.

An overtaxed charger will deplete its energy buffers first, always charging as many robots as it can with it. This means that power hiccups shouldn't cause the system to stop, but if it isn't resolved fast enough it'll end with with robots recharging on the roboport, as shown above.

Easy solution though: *chargers that point to the same roboport will share their work load*, so just add more chargers (and don't forget the modules)! It can also pay to wait, as it could indeed just be the equivalent for rush hour for your network. Still, if you see the alert, it won't hurt to construct additional chargers.

~~Maybe I should have called them energy pylons instead.~~

## UPS Considerations

Sorry to say but charging robots can be a bit demanding on one's machine. You may not notice this on a regular playthrough, however, as one of the main focus on this mod is optimization, by near necessity.

Even so, if you're finding your game is chugging behind, or the opposite, that chargers seem to be under performing, please check the mod settings (Options → Mod Settings → Map). They're specific to each savegame so you can further customise your experience.

![mod settings screenshot for v0.6](https://i.imgur.com/hoYDh8f.png)

Each option has a helpful hover-text explaining what they do, but if you need a quick primer to boost your performance: *turn off charging beams* and *decrease the recharges per second*. Bots per second can also help if decreased but from my testing, usually not with as much impact as the other two. If anything, I recommend **increasing it** for megabases, although ~maths~ says that shouldn't be necessary until you reach the equivalent of a +4GW demanding robot equivalent on the basegame.

## Power usage

To know why a charger is requiring that much power, you first must know how much a robot truly costs to run. Fair warning, excessive amounts of maths follows (for those that need it!), feel free to skip to the end for the explanation and final values.

Unless stated otherwise, the values given are the ones used in the basegame for both robot kinds, and in-game bonuses, while displayed as `+300%`, are taken into account as `400%` respectively.

A robot's power usage can be calculated as follows:

```maths
∆E(bot) = drain + movement cost * speed * worker speed bonus
```

- *Drain* and *movement cost* can be gathered from a robot's tooltip, they're the `3kW + 5kJ/m`, respectively.
- *Speed* isn't directly stated in-game but its max is `3m/s` for logistic robots and `3.6m/s` for construction robots (decreases to `20%` while out of charge).
- *Worker speed bonus* can be found from the Bonuses tab, and as such it goes from `100%` (no research) to `340%` (pre-space science) and beyond (`340 + 65(L-5)%` where `L` is the level of worker robot speed research).

This means that the more *Worker Robot Speed* research obtained the higher a bot's energy maintenance will be, and that construction robots are always slightly more power hungry.

And as such, a bot's power usage will go from `3kW` (both robots on a standstill), to `18-21kW` (logistics and construction, no speed research), and then to `54-64.2kW` (max speed research before space science). Basegame worse case, with `L` as the level of worker robot speed research, will be `3+18(3.4 + 0.65(L-5))kW`.

---

Alongside constant power usage, it's also useful to calculate how much energy a robot needs when it heads for recharging on a roboport, and it can be summarised as it follows:

```maths
capacity * (1 - charge threshold) < E(bot) ≤ capacity

capacity(bot) = max energy * worker battery bonus
```

- *Charge threshold*, the limit on which a robot will drop its current task and attempt to move to the nearest free roboport and charge, at `20%`.
- *Max energy*, how much power a single robot can store on its internal buffer by default, it being `1.5MJ`.
- *Worker battery bonus* is a non-basegame force bonus for a robot's internal energy buffer, same logic as with speed bonus above. One easy way to access it is with this [research-based mod by Klonan](https://mods.factorio.com/mods/Klonan/Robot_Battery_Research) but otherwise assume it as `100%` (ignore it).

So this means that, excluding any worker battery bonus (that just makes the amount bigger by that amount), robots will tend to require charging of `1.2MJ` up to `1.5MJ`, per each.

Using the previous data for energy consumption, this means that a base speed construction robot would take almost a full minute, `57.1s`, before heading to charge (and take 14 more seconds before running completely out of power), while on pre-space science research that time decreases to `18.7s` (and 5 seconds until complete lack of charge).

---

Okay a few remaining stray data points and where to fetch them from the game's (or mod's) files.

Electrical entities in Factorio have certain performance values in common, where we'll list three relevant ones:

- *Buffer capacity*, how much power an entity can hold (what we called *max energy* for robots). Measured on `J` on the prototype as `energy_source.buffer_capacity`.
- *Input limit*, how much power the entity can drain from the network at once. Measured on `W`, on the prototype as `energy_source.input_flow_limit`.
- *Power usage*, how much power the entity uses to function. Measured also on `W`, on the prototype as `energy_usage`.
  - As an aside, robots instead have `energy_per_tick` and `energy_per_move`, both `J`, that equate to the *drain* and *movement cost* mentioned above. A tick is `1/60s`, usually, it being the atomic time measure for game calculations.

Roboports have a buffer capacity of `100MJ` (!), an input limit of `5MW` and power usage of `50kW`. Beyond these, they also have `charging_energy`, the rate of energy they can supply to a charging robot, it being at `1000kW = 1MW`.

As a basegame roboport has four charging spots, it means each individual roboport can charge `4MW` of robot juice at max, at four robots at a time too. To note that, when sufficiently topped off, a roboport will not touch its internal buffer (both charging and its default power usage do not surpass its input limit).

Chargers have, as of v0.6.0, `25MJ` of buffer capacity, an input limit of `10MJ` and a idle power usage (as `energy_source.drain` in the prototype) of `612kW`. Because chargers are bot-uncapped (well, taking performance settings), they can recharge as many robots as possible with a `25MJ` burst when fully topped, but reliably can only do up to their input limit of `10MJ`, or else they'll be overtaxed. This is to contrast with roboports, which use their buffer for electrical "rainy days", we could say.

Of course, that's before including their performance penalty, that is at `300%` without modules, and `150%` when with max basegame modules (two efficiency 3), or with module usage deactivated. This is spoken in more detail on the Modules subsection.

Finally, a robot's *charge threshold* is on their prototype as `min_to_charge` and *speed* as, well, `speed` at `m/tick` (so multiply by 60 to get the values I used above).

## Conclusions

All right, that was a lot of numbers and technical talk, thank you for sticking around if you did. So, to finally answer the question, there are two main, well three, reasons chargers are power-hogs:

**(1) Chargers only work at 33.3% efficiency by default**, that is, they take __***3x***__ the necessary power to charge robots, unless you use efficiency modules to make it less penalising (up to *1.5x*). So for any `1kW` of power needed to charge a robot, we'll need `3kW` (down to 1.5MW) instead.

**(2) Robots are rather energy intensive to begin with**. That's the reason robot bases usually have roboports as their main power consumer, both because a roboport tops off any returning robots and any recharging that has to happen in between logistical tasks. And this only gets worse because...

**(2.5) The faster a robot is, the more power over time it'll consume**. Basegame robots, without any research, only need to recharge every minute or so, taking up to `1.5MJ` to do so. But with all worker speed research (pre-space), that decreases to every 20 seconds, the same amount of power still. And the interval only gets smaller the more research you do.

So how much can a single charger do? Well, depends on a few things. How fast bots are going? Are you thinking on a single burst or over time (as of v0.6, bots are charged when they would instead head to a roboport so at `+1.2MJ` consumption per robot, instead of the gradual topping off of previous versions)? Base efficiency or using modules?

*In a burst, a single barren charger can charge 6-7 robots* (no matter how fast or what kind the robots are).

*Over time, a single barren charger can keep in average 149-174 robots charged up* (all logistic and all construction robots respectively) without any speed research. *With max speed, pre-space science, that goes down to 49-58*.

**Max module efficiency essentially doubles charger capacity**, so that goes to *11-14*, *298-348* and *97-116* respectively.

If that sounds low, don't worry: because robots go faster, from the speed research, and don't need to stop or slow down as much to charge, your robotic demands will be smaller with chargers around compared to a basegame base. That and chargers work in tandem when connected to the same roboport, so for each additional charger you get more and more energy bandwidth!

### Modules

Okay, last bit of maths.

A charger's base has a `distribution_effectivity` of 0.5 (same as basegame beacons), having two possible module slots that only accept consumption-effecting modules (so, effectivity ones, the green forgotten ones). Thankfully the game does most of the adding up and maths for you, as long as you add the target modules inside the charger before checking its bio.

![a charger's bio, highlighting energy consumption](https://i.imgur.com/KxtxUgJ.png)

A charger's energy usage will be as such:

```maths
Ef(charger) = need * 3(1 + energy consumption)
```

- *Need* is how much energy a charger needs, like per example, `1.5MJ` to completely charge off a basegame robot.
- *Energy consumption* is the effect the charger will have upon itself, already taking the distribution effectivity and the total of its containing modules into account. In the picture above (one effectivity module 3 and one effectivity module 1), that equals `-40%`.

Because the max you can get in the base game is effectivity 3, with `-50%` consumption, this also means that, at best, `Ef(charger) = 1.5 * need`. Like vanilla chargers, the value is effectively capped at `-80%` (even if it doesn't show in the charger interface), so you can reach up to `60%` power consumption, rules of thermodynamics be damned.

Even adding a single effectivity 1 module grants you a `-15%` energy consumption, which equals `255%` power consumption, so it's really within your best interests to at least add even the more barebones modules into chargers (and they're required research to unlock Charge Transmission, so ye).

Recipe-wise, it is the mod developer's opinion that **two efficiency 2 modules is the optimal basegame setup**, taking ingredient and power cost into consideration, as with effectivity 3 modules, each more expensive than a single charger to craft, still having a use for scenarios where you don't have more space to add additional chargers.

## FAQ

### My charger doesn't seem to be doing anything

~~Well, chargers don't have any particle effects, by design (lag, ya know) to warn they've charged a bot.~~ As of v0.6 that shouldn't be an issue any more because of the (on-by-default) charging beams. Sadly, the antenna spin seems to... not work any more. Make sure the charger is connected to a target (see below) and powered.

### Okay, my chargers don't seem to be doing enough

Okay, that's something different. There's a few possible solutions, most telegraphed by the game itself.

1. Charger isn't paired to any roboport
1. Charger is overtaxed (orange alert)
1. Energy supply isn't enough to keep the charger powered up
1. Rate of robots charged per tick is too low

For the first one, hover your mouse over the charger's display and see if it points to any roboport. If not, pick and place the charger on a more suitable (closer) place.

The second and third issues are usually telegraphed in-game by orange alerts. You can also see this happening if, when hovering a charger's display, the shown electricity bar is consistently on the red. If that's the case, either add more chargers (if you have enough power) or boost your power production.

For the last one, you'll need to increase the performance settings (see UPS considerations above), and see if that does help or not.

### My game is lagging

Hey, don't point fingers at me right away. Check performance statistics with F6 and try decreasing your game graphical settings first, but if you're sure CT is behind any lag, please check UPS considerations above. I got ya covered!

Also if nothing of this does help your game, consider this as a bug and please check the following FAQ.

### I found a bug! Please fix it

Sure! But I'll need a bug report for it. Follow the forum guidelines for bug reporting, so that means: describing what you were doing (+ steps to replicate the issue), what other mods you have installed (in a .zip archive), what version of this mod you have and sending me your bugged save-game alongside your /mods folder. All these steps will make your issue much easier to diagnose and to be fixed.

***DO NOT post your bug report here on the mod portal***, as it doesn't notify the mod maintainers about new posts or replies so it may take literal weeks for stuff to be noticed. Please, *please*, use the [forum thread](https://forums.factorio.com/viewtopic.php?f=97&t=49853) or [github repo](https://github.com/dustine/ChargeTransmission/issues) to make your bug report.

## Credits

Special thanks to:

- Mike C for the concept and not giving up on it
- Xterminator for the video spotlight of v0.5
- [KatherineOfSkies](https://www.youtube.com/channel/UCTIV3KbAvaGEyNjoMoNaGtQ/) for her friendly and welcoming community
- desseb for being key on the brainstorming and play-testing
- Nexela for general code help and workarounds
- eradicator for crucial help with ups optimizations

This mod contains graphics adapted from the icons made by [Roundicons](http://www.flaticon.com/authors/roundicons) and [Gregor Cresnar](http://www.flaticon.com/authors/gregor-cresnar) from [www.flaticon.com](http://www.flaticon.com) under a [CC 3.0 BY](http://creativecommons.org/licenses/by/3.0/) license.