# Felles spillsystemer

## Askemåler

Alle klasser samler aske fra fiender. Når måleren er full kan ultimate-evnen utløses. For mye aske over tid begynner å forbanne spilleren, så den bør brukes.

## Kronefragmenter

Spillets unike system. Legendariske gjenstander som endrer en evne kraftig, men alltid med en ulempe. Å samle alle fragmentene er også hovedmålet i historien.

## Evnemodifikatorer

Hver evne har 3–5 varianter (f.eks. at *Bone Lance* blir giftig, deler seg eller fryser).

## Kontroller

- To museknapper + fire evneplasser
- Skal fungere med både tastatur/mus og håndkontroll

## Valg på slutten

Spilleren kan knuse kronen eller bli den nye Askekongen.

## Karakterer

- Valgfritt kjønn og utseende for alle klasser
- Hver klasse har egen dialog og sitt eget forhold til Askekongen


## Verden (beta 0.3)

- Én sammenhengende verden med landsbyen **Cinderfall** og tolv soner fordelt på seks acts. Bare hus og gruver er egne økter.
- Kartet viser omrisset av hele verden fra start. Utforsket område fylles inn, og man kan sette egne markører.
- Veivisning: stiplet sti og pil mot det aktive questet (eller mot egen markør).
- Hver sone har egne fiender som ikke finnes andre steder. I noen soner stiger fiender opp av jord og stein, men sjelden.
- Fiender reagerer bare på kort avstand og vandrer ellers rundt.

## Gjenstander og loot

- Fire sjeldenhetsnivåer (Common, Magic, Rare, Ashforged), seks utstyrsplasser, holdbarhet og reparasjon hos smeden.
- Kister (vanlige og jernkister), loot fra fiender, elites, champions og bosser. Alt styres av tabellene i `items.gd` og `Data.GRIND`.
- Smed, mystiker og stash (delt mellom karakterer, egen for hardcore). Helsedrikk med nedkjøling, som i Diablo 3.

## Quests og bosser

- Hovedhistorien har 13 kapitler i rekkefølge, fra Maren's Cellar til Askekongen. Hver champion eller boss finnes bare mens quest'en er aktiv.
- Sidequests: bounties per sone (drep, kister, elites).
- Recall-sigil (T) tar deg til landsbyen, waypoints kan bare brukes til steder du har vært.

## Karakter

- Navn og utseende, 20 vanskelighetsgrader (byttes ett steg om gangen), hardcore med Hall of the Fallen.
- Skill tree som starter blankt. Lagrede karakterer. Statistikk på tittelskjermen.
- Grafikkinnstillinger (kvalitet, glød, kantutjevning, VSync, FPS-grense), FPS-teller og voice lines med undertekster.

## Stemme, cutscenes og fiender (beta 0.3.1)

- Voice lines bruker systemets talesyntese hvis den finnes (`speech-dispatcher` og `espeak-ng`). Uten den bruker spillet en egen formantsyntese med egen stemme per karakter og klasse. Den er et stemmemurmel, ikke tale. Ekte innspilte replikker kan legges inn i `Voice.speak()`.
- Cutscenes er malte, animerte scener tegnet fra former: brennende by, kongen med kronen, én scene per act og kongen før bosskampen.
- Hver variant av en fiende har eget tilbehør og animasjon (horn, vinger, klokker, flammer, hjelmlykter, magmasprekker) på toppen av grunnformen. Se `enemy_looks.gd`.
