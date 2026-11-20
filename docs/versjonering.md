# Versjonering

Spillet er i **beta**. Versjonen vises nederst til venstre på alle skjermer.

Format: `0.MILEPÆL.BYGG`

- **0** blir stående til utgivelse (da blir det 1.0.0).
- **MILEPÆL** øker når et stort system lander:
  - 0.1: spillbar prototype (tre klasser, fem soner)
  - 0.2: gjenstander, loot, landsby, quests
  - 0.3: én sammenhengende verden med seks acts, lagring, skill tree, hardcore
  - 0.4: tutorials, Crownbearer, nytt tema
  - 0.5: ny grafikk (terreng i relieff, tegnestil med blekk, etterbehandling)
  - 0.6: nytt navn (Pyrewake), skills som i Diablo 3 (runer og passiver låses opp med level), tregere progresjon og sjeldnere loot
- **BYGG** øker for feilrettinger og balansering mellom milepæler.

Versjonen står i `Game.VERSION` ([game/scripts/autoload/game.gd](../game/scripts/autoload/game.gd)).
