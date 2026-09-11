
extension LevelRunner {
 var probeRoadPoints: [Point] { [] }
 func probeHeroMovement() -> [String:Any] {
  var checks: [[String:Any]]=[]
  for hero in hudHeroes {
   guard let index=hudHeroIndex(for:hero.id) else { continue }
   let before=heroPosts[index].unit.position
   let path=paths.min { $0.points.last!.distance(to:before) < $1.points.last!.distance(to:before) }!
   let destination=path.point(atDistance:path.totalLength*0.25)
   selectHero(heroID:hero.id)
   let selected=selectedHeroIndex == index
   commandSelectedHero(to:CGPoint(x:destination.x,y:destination.y))
   for _ in 0..<120 {
    var claimed=Set<Int>(),killed=Set<Int>()
    stepHeroesTick(claimed:&claimed,killedIDs:&killed,indexByWalkerID:[:])
   }
   publishHeroes()
   let after=heroPosts[index].unit.position
   checks.append(["hero":hero.shortName,"selected":selected,"commandAccepted":selectedHeroIndex == nil,
    "distanceMoved":before.distance(to:after),"before":[before.x,before.y],"after":[after.x,after.y],
    "destination":[destination.x,destination.y],"routeNodesRemaining":heroPosts[index].route.count])
  }
  return ["passed":isReady && !checks.isEmpty && checks.allSatisfy { ($0["distanceMoved"] as! Double)>30 },
   "checks":checks,"ready":isReady,"status":status,"device":UIDevice.current.model,
   "systemVersion":UIDevice.current.systemVersion,"timestamp":Date().description]
 }
}
