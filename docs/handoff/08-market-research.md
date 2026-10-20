# Market research (Apify, 2026-10-18 to 2026-10-20)

Each task's full write-up and CSV is in `/mnt/project-files/research/apify/<task>/`. Total Apify spend for the first ten tasks was about $6.20. No personal data on individuals was stored.

## App store keywords (`aso/`)
- Open on iOS: "running partner" (top 5 all have 0–4 ratings), "find running group", "training partner", long-tail "run club near me". Crowded: "workout partner" (iOS), "workout buddy app", "fitness friends".
- Existing partner finders are all small: Sweatmates (14k, couples accountability, not a matcher), AtClub, Sportpartner, BFF, Actively, GymBuddy clones, MileMatch, Running Mate, ODDS Running.
- Safety is almost absent from titles, an opening for the trust angle.
- Format winners use: "Brand: Find [X] Partners". Title ideas: "Groundwork: Training Partners" (29 chars) or "Groundwork: Run & Gym Partners" (30). Subtitle: "Meet runners & lifters near you" or "Safe local run clubs & buddies". Keywords: `buddy,gym,running,group,club,runclub,meetup,friends,cycling,climbing,triathlon,local,together,crew,arlington`. Rework once the name changes.

## Competitor reviews (`competitor-reviews/`, 1,061 reviews: Strava, Meetup, BFF, Peanut, Trybe, RunMatch, GymBuddy)
Top pain points: paying just to connect; billing traps; ghosting and inactive users; too few people nearby; distance and age filters ignored; bots and scammers in groups; opaque moderation and verification lockouts; can't log in; dead or priced-out groups; lost activity data. Also: teens (16–17) and parents complaining they can't join BFF.
**Implications:** never charge for connecting; launch dense (clubs, a few metros), show active-nearby counts, expire stale profiles; hard filters; visible, fair trust (fallback when verification fails, a reason for every warning, appeals); multiple sign-in methods and offline-safe logging.

## Reddit (`community/`, 127 on-topic posts)
Most posts are hand-written partner ads listing area, days, time, pace and goal race, which are Groundwork's profile fields. Pace mismatch (37) and scheduling (32) dominate. Clubs help some and put others off. Strava works as a stand-in social network with no way to meet. Beginners need a low-pressure first step. Users set their own safety rules (same-gender, chat first, public places). Several solo-built gym-buddy apps, no winner. Local DMV demand shows in r/nova and r/washingtondc. Matching implications are in `01-product.md`.

## Races and launch timing (`events/`, 97 races within 50 miles of 22201)
Marine Corps Marathon 25 Oct 2026 (recruit beta testers). January is quiet but motivated. **Best launch: late January or early February 2027**, 8–12 weeks before spring races (Half Donkey 6 Mar, Reston 10 Miler 7 Mar, Cherry Blossom early April, PNC Alexandria Half and Run Thru Reston 25 Apr). Second push in June for fall marathon training. Missing: Pacers events, Cherry Blossom, Army Ten-Miler, 5Ks, cycling (BikeReg). Data is in `public.local_events` and refreshes monthly.

## Venues (`venues/`, 323 in `public.venues`)
Gyms, parks, tracks, trailheads, run stores, climbing gyms, bike shops and more across the pilot zones, with 40 flagged as partner-workout candidates (run stores that host group runs, climbing gyms, bike shops, CrossFit, public meeting points such as the W&OD trailhead and Lubber Run). Seed data only; replace from a licensed Places API before launch.

## Clubs to contact (`outreach/`, 37 in `private.outreach_orgs`)
First ten: Pacers Running Clarendon, PR Run & Walk + Ballston Run Club, Clarendon Run Club, Ballston Runaways, DC Road Runners, NOVA Running Club, **DC Triathlon Club (Garmin beta source)**, Potomac Pedalers, Del Ray Running Club, Trek Clarendon. RRCA's national office is in Rosslyn. Meeting times are from third-party lists; confirm before contacting.

## Sponsors and co-hosts (`partners/`, 23 in `private.partner_orgs`)
Top: Pacers, PR Run & Walk, lululemon, Nuun (formal run-club program), HOKA, Brooks, Tracksmith, Trek Clarendon, Compass Coffee Ballston, Momentous Sports Medicine, Arc'teryx, Garmin, Road Runner Sports, Movement Crystal City, District Running Collective. Pitch product and co-branding, not cash; a "find your pace partner" social run is the easy first ask.

## Competitor to watch
**Sweatmates: Partner Fitness** (launched Dec 2025, 14k ratings): couples and friends accountability, doesn't match strangers.
