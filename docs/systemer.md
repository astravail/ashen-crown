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

## Tutorials (0.4.0)

`scripts/ui/tutorial.gd`. Små kort med animert demo, tittel og forklaring dukker opp første gang en situasjon oppstår (bevegelse, første fiende, loot, kiste, waypoint, osv.). De pauser ikke spillet. Enter lukker kortet. Av/på og «Show all tips again» ligger i Settings (`settings.tutorials`, `settings.tut_seen`). Nye tips legges i `Tutorial.TIPS`, en demo i `TutDemo._d_<navn>`, og utløseren i `Tutorial._scan()`.

## Crownbearer (0.4.0)

Femte klasse, låst til man har fullført historien én gang (`Game.class_unlocked`, `records.wins`). Vises i karattervalget med forklaring når man prøver å velge den. Tallene står i `Data.CLASSES.crownbearer` og i `Player.dmg_mult/cd_rate`.

## Tema (0.4.0)

Diablo-inspirert: blodrød og gammelt gull på sverted stein. Rammer lages prosedyrisk i `scripts/ui/ornate.gd` og brukes av temaet, kortene og HUD.

## Grafikk (0.5.0)

Alt tegnes fortsatt i kode, uten bildefiler. Utseendet bæres av tre ting:

- **Terreng** (`shaders/ground.gdshader`, `shaders/terrain.gdshaderinc`, glød i `shaders/veins.gdshader`). Hvert underlag er et høydefelt i tillegg til en farge, så lysene i scenen tegner frem hver stein og rot. Mønstrene velges med `pattern` i sonedataene: 0 tråkket jord med kjerrespor, 1 heller, 2 myr, 3 vulkanske plater, 4 skogbunn, 5 katakombefliser. Bakke man ikke kan gå på er hevet: veggen viser en front mot sør, kaster skygge og forsvinner i mørket bakover.
- **Tegnestil** (`scripts/fx/ink.gd`). Figurer og props er former med blekkontur, lyse øverst og mørke ved foten, med en tynn lyskant mot fakkelen og en myk skygge under. Ting som lyser er myke: en glorie med en liten varm kjerne. Nye ting tegnes med `Ink.shape`, `Ink.limb`, `Ink.oval`, `Ink.dot`, `Ink.glow` og `Ink.flame`.
- **Etterbehandling** (`scripts/fx/post_fx.gd`, `shaders/post.gdshader`). Fargegradering, tåke, vignett og filmkorn legges over verden, aldri over HUD og menyer. Utseendet per underlag står i `PostFX.LOOKS`.

Ytelse: `draw_polygon`, `draw_circle`, `draw_polyline` og `draw_arc` får grafikkortet til å opprette egne buffere for hvert kall, og svake drivere tåler bare noen tusen. Derfor er konturer multilinjer, lemmer og flammer primitiver, og prikker og glød teksturerte rektangler. Props langt fra bildet sover uten tegnekommandoer (`World._tend_props`), og en prop som ikke beveger seg tegnes én gang (`Prop.LIVE`, `Prop.LIVE_GLOW`).

Stillbilder i fast størrelse, uansett vindu: `godot --path game res://scripts/debug/shots.tscn -- --out=/tmp/shots --views=title,village,zone0,fight1,gallery,props,loot,cuts,boss,interior [--quality=0..3] [--class=knight|gravecaller|pyrewitch] [--bench]`. Kjør det med `XDG_DATA_HOME` satt til en midlertidig mappe, så rører det ikke egne lagringer.
