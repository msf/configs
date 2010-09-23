#!/usr/bin/env python
#

"""
// The DoTurn function is where your code goes. The PlanetWars object contains
// the state of the game, including information about all planets and fleets
// that currently exist. Inside this function, you issue orders using the
// pw.IssueOrder() function. For example, to send 10 ships from planet 3 to
// planet 8, you would say pw.IssueOrder(3, 8, 10).
//
// There is already a basic strategy in place here. You can use it as a
// starting point, or you can throw it out entirely and replace it with your
// own. Check out the tutorials and articles on the contest website at
// http://www.ai-contest.com/resources.
"""

from PlanetWars import PlanetWars

def SelectShipCount(max_ships, min_ships):
  ratio = 3
  if min_ships < max_ships/ratio:
    return max_ships/ratio
  return min_ships

def ScoreSourcePlanet(planet_fleets, planet):
  if planet_fleets > 1:
    return -1
  return float(planet.NumShips())

def PrintAction(action):
    print("orig: %r -> dest: %r, #SHIPS: %d, fleets for orig: %d\n" % \
          ( action['orig'], action['dest'], action['num_ships'], action[ action['orig'] ] ) )

def DoTurn(pw, old_ctx):
  context = old_ctx
  # (1) If we currently have a fleet in flight, just do nothing.
  if len(pw.MyFleets()) >= 4:
    return
  # (2) Find my strongest planet.
  source = -1
  source_score = -999999.0
  source_num_ships = 0
  my_planets = pw.MyPlanets()
  for p in my_planets:
    planet_fleets = context.setdefault( p.PlanetID(), 0)
    score = ScoreSourcePlanet( planet_fleets, p)
    if score > source_score:
      source_score = score
      source = p.PlanetID()
      source_num_ships = p.NumShips()

  # (3) Find the weakest enemy or neutral planet.
  dest = -1
  dest_score = -999999.0
  dest_num_ships = 0
  not_my_planets = pw.NotMyPlanets()
  for p in not_my_planets:
    score = 1.0 / (1 + p.NumShips())
    if score > dest_score:
      dest_score = score
      dest = p.PlanetID()
      dest_num_ships = p.NumShips()

  # (4) Send half the ships from my strongest planet to the weakest
  # planet that I do not own.
  num_ships = SelectShipCount(source_num_ships, dest_num_ships)

  context['num_ships'] = num_ships
  context['dest'] = dest
  context['orig'] = source
  context[source] = 1 + context.setdefault(source, 0)
  pw.IssueOrder(source, dest, num_ships)
  print("%r->%r" % ( source, dest ))
  PrintAction(context)
  return context


def main():
  map_data = ''
  context =  { 'orig':0, 'dest':0, 'num_ships':0 }
  while(True):
    current_line = raw_input()
    if len(current_line) >= 2 and current_line.startswith("go"):
      pw = PlanetWars(map_data)
      context = DoTurn(pw, context)
      pw.FinishTurn()
      map_data = ''
    else:
      map_data += current_line + '\n'


if __name__ == '__main__':
  try:
    import psyco
    psyco.full()
  except ImportError:
    pass
  try:
    main()
  except KeyboardInterrupt:
    print 'ctrl-c, leaving ...'
