# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

- Talent window: shows the next 5 talent POINTS instead of the next 5 talents. A talent that gets several points shows all their numbers (for example "2-4"), and the strip above the talent window lists the plan with the rank and the level each point is spent at ("Gift of Nature 2-5/5 (now-29) > Nature's Swiftness 1/1 (lv 30)").
- New setting "Sell advice" (off by default, needs Auctionator): items that are not an upgrade get a tooltip line saying whether to sell them on the auction house, disenchant them or just vendor them, using the prices Auctionator has scanned (AH cut included, soulbound items skip the AH). Also `/mentor sell on|off`. In the bags these items get a small gold coin (sell on the AH) or disenchant icon in the top-left corner, in place of the arrow. Prices are shown with the game's gold, silver and copper coin icons.
- Item tooltips start with what to do, right after "Mentor:": "Equip" (or "Equip at level 24"), "Keep - upgrade for <other spec>" (the spec with the biggest gain), or the sell advice. Items that are an upgrade for another of your specs are never marked for selling.
- Item tooltips are shorter: the spec lines show only the arrow and the percentages ("Balance: +0.2% total (item +6%)") without the words "Tiny upgrade" / "Much worse".
- New setting "Tooltip details" (on by default): turn it off to hide the stat explanations, the total/item legend and the extra prices, so the tooltip only shows the verdicts. Also `/mentor details on|off`.
- Sell advice now always says something for gear: "Just vendor it" with the reason in grey (soulbound, or no AH price yet) when the AH and disenchanting are not worth it, and "Sell advice needs the Auctionator addon" when Auctionator is missing.
- Sell advice works for every item with a price (cloth, hides, herbs ...), not only gear. Stackable items show the price "each", and the minimum gain (10 silver) is counted for a full stack, so cheap reagents that are worth much more on the AH are no longer sent to the vendor.
- Crafting reagents for one of your professions say "Keep for Tailoring" (cloth also for First Aid, hides for Leatherworking, herbs for Alchemy, and so on) instead of "sell".
- New Mentor logo as the minimap button and the addon list icon.

## 1.9.0 - 2026-11-10

Better bug reporting.

- Errors inside Mentor are caught automatically (where they happened and how often). One chat hint per session points to `/mentor bug`.
- New "Report bug" window: pick the type of problem, describe it, and shift-click items into the text to attach them (tooltip text, stats and the verdict per spec are included).
- The finished report comes with a link to the bug report form on GitHub.
- The Report bug button shows how many errors have been caught.

## 1.8.0 - 2026-11-09

First release on CurseForge.
