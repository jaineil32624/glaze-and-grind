# Glaze & Grind — Game Design Document

**Version:** 0.1 (Alpha vertical slice) · **Engine:** Godot 4.3+ · **Platforms:** Windows, Linux, macOS, Web, Android (iOS via Xcode export)

---

## 1. Pitch

You run **Glaze & Grind**, a bright cartoon donut-and-coffee shop. Customers flood in during the morning rush, your crew fries, glazes, brews and steams on their own — and you're the manager who decides who works where, what to stock, which machines to buy, and when to jump in and pull a batch out of the fryer yourself.

Survive the rush, build a five-star reputation, open new locations, and climb from **Trainee** to **CEO**.

**Genre blend (target):** 40% Tycoon · 30% Restaurant management · 15% Employee simulation · 10% Logistics · 5% Sandbox

**Comparable titles:** Papa's Donuteria (hands-on cooking), Diner Dash (time pressure), Coffee Shop Tycoon (business layer), Two Point Hospital (autonomous staff with stats).

## 2. Design pillars

1. **The rush is the drama.** Traffic follows a real day curve. Rushes should feel tense, the afternoon lull should feel like a breather you use to restock and rest staff.
2. **Your crew is alive.** Employees decide what to do on their own, get stressed, make mistakes, and get better. The player manages people, not a cursor.
3. **Every dollar is a decision.** Restocking, wages, upgrades and expansion all compete for the same money. The end-of-day ledger tells you exactly why you won or lost.
4. **Hands-on when you want it.** Tap the fryer to take over the pull and nail a perfect batch. Optional, but it rewards attention.
5. **Moddable by design.** Recipes, customers, equipment, stores and events are all JSON. The base game is loaded the same way mods are.

## 3. Core loop

```
 ┌────────────── DAY (≈5 real minutes, 6:00 → 20:00) ──────────────┐
 │ Customers arrive → order at register → crew makes items →        │
 │ order assembled at pickup → customer pays + tips → rating moves  │
 │ Player: assign focus, hire temp help, take over fryer, emergency │
 │ restock, react to random events                                   │
 └───────────────────────────────┬──────────────────────────────────┘
                                 ▼
                   END-OF-DAY LEDGER (revenue, costs, profit)
                                 ▼
          MANAGEMENT PHASE: restock · hire/fire · upgrade · expand
                                 ▼
                      Autosave → next day
```

## 4. The store

Top-down view, single screen, responsive to any aspect ratio.

| Zone | Contents |
|---|---|
| Kitchen (back) | Mixer, Fryer, Glaze & Topping table, Coffee bar, Cold bar, Break room |
| Counter (middle) | Register(s), Pickup counter, Display case |
| Floor (front) | Entrance, queue line, pickup waiting area |

## 5. Production

### 5.1 Donut line (batch production → display case)
Donuts are made in batches to keep the display case stocked, the way real shops work.

| Step | Station | Consumes | Produces |
|---|---|---|---|
| Mix & knead dough | Mixer | flour, sugar, yeast, milk | 12 dough |
| Cut & fry batch | Fryer | 6 dough | 6 fried rings (quality from fry timing) |
| Cool, ice & top | Glaze table | per-donut toppings (chocolate, sprinkles, syrup, fruit) | 6 finished donuts into case |
| Package | Pickup | boxes (for 3+ donuts) | — |

**Fry timing:** each batch has a quality curve peaking at the perfect pull time. Employees pull based on Accuracy (with noise); the player can tap the fryer to take over and stop a sweeping needle. Over-fried = burned (wasted), under-fried = low quality.

**Par levels:** the crew auto-generates production tasks when a donut's case count drops below its par level (player-adjustable).

### 5.2 Drinks (made to order)
| Drink | Station | Steps (flavour) | Skill level |
|---|---|---|---|
| Hot Coffee | Coffee bar | grind → brew | 1 |
| Tea | Coffee bar | steep | 1 |
| Espresso | Coffee bar | grind → pull shot | 2 |
| Latte | Coffee bar | shot → steam milk → pour | 2 |
| Cappuccino | Coffee bar | shot → foam milk → pour | 2 |
| Iced Coffee | Cold bar | brew → ice | 1 |
| Refresher | Cold bar | fruit base → shake over ice | 1 |
| Frozen Coffee | Cold bar (needs Blender) | blend | 3 |

Drinks can carry a **flavour shot** (syrup) for +$0.50.

## 6. Customers

Each customer has **Patience, Mood, Order complexity, Loyalty, Spending level, Favourite items**.

| Type | Patience | Spend | Behaviour |
|---|---|---|---|
| Student | Medium | Low | Cheap drinks, often iced/refreshers, comes in groups during school events |
| Business Worker | Low | High | Coffee + 1 donut, hates waiting, peak in morning rush |
| Family | High | High | Big orders, boxes of donuts |
| Tourist | High | Medium | Tries something new, tips well when happy |
| Influencer | Medium | Medium | A great visit can go **viral** (traffic boost); a bad one hurts rating |
| Food Critic | Medium | Medium | Rare. Their review counts ×5 toward store rating |

**Mood** drains while waiting (rate = 1/patience) and is adjusted on service by order quality and accuracy. Leaving angry hurts rating; leaving delighted builds loyalty (returning customers spend more).

If a favourite item is out of stock, the customer picks an alternative (small mood hit) or leaves.

## 7. Employees

### 7.1 Stats
| Stat | Range | Effect |
|---|---|---|
| Speed | 1–10 | Work and walk speed |
| Accuracy | 1–10 | Mistake chance, fry-pull precision |
| Intelligence | 1–10 | XP gain rate, task choice quality |
| Teamwork | 1–10 | Willingness to assist busy coworkers, assist bonus |
| Reliability | 1–10 | Chance of arriving late / calling in sick |
| Stress | 0–100 | Rises while working in rushes; >75 doubles mistakes; >90 forces a break |
| Happiness | 0–100 | Falls with stress/overwork, rises with breaks & raises; low happiness → quits |
| Experience | XP/level | Levels 1–5; unlock skills, small stat growth |

**Personalities:** Cheerful (stress builds slower), Perfectionist (accurate, slower), Speedy (fast, sloppier), Chatty (+customer mood at register, slower), Steady (no modifiers).

### 7.2 Mistakes
Burned batch · Spilled drink · Wrong order · Forgot topping · Late arrival · Over-fried. Each mistake has a cost (wasted ingredients, time, or mood) and is logged on the dashboard.

### 7.3 Skill unlocks
Level 1: Register, Mixer, Fryer, Glaze, Brew, Tea, Pack · Level 2: Espresso drinks · Level 3: Blender / frozen drinks · Level 4+: speed and accuracy growth.

### 7.4 Behaviour tree (summary)
```
Selector
├─ Sequence: [Stress > break threshold] → walk to break room → rest
├─ Sequence: [Has claimed task] → walk to station → work (may fail → mistake)
├─ Sequence: [Find best task] (priority × skill × focus × distance)
├─ Sequence: [Coworker busy & Teamwork roll] → assist (speeds their task)
└─ Clean (raises cleanliness for health inspections)
```

## 8. Day structure & events

| Time | Phase | Traffic |
|---|---|---|
| 6:00–9:30 | Morning Rush | ███████ |
| 9:30–11:30 | Late Morning | ███ |
| 11:30–13:30 | Lunch Rush | █████ |
| 13:30–16:30 | Afternoon Slowdown | ██ |
| 16:30–18:30 | Evening Rush | ████ |
| 18:30–20:00 | Closing | █ |

Lighting shifts from dawn → day → dusk → night with lamps turning on.

**Random events** (one may trigger per day, weighted by store and day):
Snow Day (−traffic, hot drinks ↑) · Holiday Rush (+traffic, families) · School Opening (students ↑) · Sports Championship (evening surge) · Equipment Breakdown (station offline until repaired) · Power Outage (fryer & coffee bar down for an hour) · Health Inspection (cleanliness & waste graded) · Employee Sickness · Viral Post (traffic ×1.6).

## 9. Economy

- **Revenue:** item prices × store price multiplier + tips.
- **Expenses:** ingredient purchases, daily wages, equipment maintenance, rent (per store), emergency delivery premium, repairs.
- **Profit/Loss** shown per day with a running history graph.
- Ingredient prices are bought in packs during the management phase; mid-day emergency restock costs 1.5× and arrives after 45 game-minutes.

## 10. Progression

### 10.1 Career
| Rank | Requirement (lifetime profit / rating) | Unlocks |
|---|---|---|
| Trainee | start | Main Street store |
| Shift Manager | $1,500 / 3.0★ | Maple Bar, Cappuccino, 2nd register, extra crew slot |
| Store Manager | $6,000 / 3.5★ | Mall store, Blender, Raspberry Jelly |
| District Manager | $20,000 / 3.8★ | Airport & Highway stores, Auto-Glazer |
| Regional Director | $60,000 / 4.2★ | City Center store, Smart Inventory |
| CEO | $150,000 / 4.5★ | Mega Flagship |

### 10.2 Stores
| Store | Traffic | Price × | Customer mix | Rent/day |
|---|---|---|---|---|
| Main Street | 1.0 | 1.0 | balanced | $40 |
| Mall | 1.3 | 1.05 | students, families | $90 |
| Highway | 1.1 | 1.1 | business, tourists, coffee-heavy | $80 |
| Airport | 1.5 | 1.35 | business, tourists, low patience | $180 |
| City Center | 1.6 | 1.2 | business, influencers | $220 |
| Mega Flagship | 2.2 | 1.3 | everyone, critics | $400 |

Owned stores you're not actively managing earn **passive daily income** based on their last rating and staff, so expansion compounds.

### 10.3 Upgrades
Fryer (batch speed, wider perfect window), Espresso machine (speed, quality), Mixer, Cold bar, Blender (unlocks frozen), Second register, Auto-Glazer (finishes batches without staff), Smart Inventory (auto-restocks to targets at end of day), Comfy Break Room (faster stress recovery), Display Case (higher par levels).

## 11. UI

- **HUD:** cash, day/time + phase, rating stars, active event banner, speed controls (pause/1×/2×/3×), emergency restock.
- **Dashboard (toggle):** live graphs for revenue/hour, profit, customer happiness, employee efficiency, food waste, order accuracy, store rating.
- **Staff cards:** tap an employee for stats, stress, mood, level, and set a Focus station.
- **Management phase:** tabs for Restock, Staff (hire/fire/raise), Upgrades, Menu (par levels), Stores, Career.
- Fully usable with mouse, touch, keyboard and gamepad.

## 12. Audio
Procedurally synthesised SFX (register chime, fryer sizzle loop, milk-steam hiss, door bell, happy/angry reactions, level-up fanfare), crowd ambience that scales with customers, and a looping lo-fi background track. All generated at runtime so the repo has no licensed audio.

## 13. Out of scope for v0.1 (see Roadmap)
Drive-thru, delivery orders, online leaderboards, Steam achievements, co-op, stock market mode, workshop browser, weather visuals beyond events.
