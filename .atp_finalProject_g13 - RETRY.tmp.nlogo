breed [cars car]
breed [junctions junction]

junctions-own [
  ; id of junction
  id

  ; the cars crossing righ now
  crossing-now

  ;car N, S, E, W
  car-N car-S car-E car-W
]

cars-own [
  ; speed of the car
  speed

  ; max speed/aim speed
  goal-speed

  ; north, south, east, west
  current-direction

  ; next intersection
  next-intersection

  ; what direction they are going to switch to
  next-direction

  ; tick at which the car reached the stopline
  arrival-time

  ; boolean showing if the car is waiting at the intersection or not
  at-junction?

  ; boolean showing if the car is currently crossing the intersection
  is-crossing?

  ; by what intersection is the car observed
  observed?

  ; indicates the next turn (right, left, straight)
  next-turn

  ; shows if the car has completed the turn in the intersection
  has-turned?
]

globals [
  ; collection of roads on the map
  roads

  ; ["north" "east" "south" "west"] helper
  clockwise

  ; acceleration of cars
  acceleration

  ; deceleration of cars
  slowdown-overshoot
]

patches-own [
  ; the direction of the road (north/south/east/west/NONE)
  direction

  ; true at the 4 patches which make up a junction
  junction-on-patch?
]

; =========================
; SETUP

; draws the ROADS and JUNCTIONS
to draw-map
  ask patches [
    set pcolor black
    set junction-on-patch? false

    ; draw the ROADS
    if (pycor mod 20 = 0) [
      set pcolor white
      set direction "east"
    ]
    if ((pycor - 1) mod 20 = 0) [
      set pcolor white
      set direction "west"
    ]
    if (pxcor mod 20 = 0) [
      set pcolor white
      set direction "south"
    ]
    if ((pxcor - 1) mod 20 = 0) [
      set pcolor white
      set direction "north"
    ]

    ; draw the JUNCTIONS
    if (((pycor mod 20 = 0) or ((pycor - 1) mod 20 = 0)) and ((pxcor mod 20 = 0) or ((pxcor - 1) mod 20 = 0))) [
      ; soft yellow
      set pcolor yellow
      set direction "NONE"
      set junction-on-patch? true
    ]
  ]
end

; creates the ROADS and JUNCTIONS
to create-roads-junctions
  ;;; define ROADS
  set roads patches with [pcolor = white]

  ;;; get yellow patches
  let candidate-patches patches with [
    pcolor = yellow and
    (pxcor mod 20 = 0) and
    ((pycor - 1) mod 20 = 0)
  ]

  ;;; initialize JUNCTIONS
  ask candidate-patches [
    sprout-junctions 1 [
      set color yellow
      set shape "square"
      set size 0.75
      setxy (pxcor + 0.5) (pycor - 0.5) ; in order to center the JUNCTION agent
      set label who
      set label-color black
      set crossing-now no-turtles
      set car-N nobody
      set car-E nobody
      set car-S nobody
      set car-W nobody
    ]

    ;;; draw patches AROUND JUNCTIONS
    ask patches with [
      pcolor = white and any? neighbors4 with [pcolor = yellow]
    ] [
      set pcolor orange
    ]
  ]
end

; creates the CAR objects and places them on the ROADS
to place-cars

  set-default-shape cars "car top"

  create-cars number-of-cars [
    set color blue
    set size 0.75
    set arrival-time -1

    ; SPEED
    set goal-speed 0.4
    set speed 0.4

    ; place cars on road, but not on the intersections
    let road-location one-of roads with [
      not any? cars-on self and
      pcolor != yellow and
      pcolor != orange
    ]
    setxy ([ pxcor ] of road-location) ([ pycor ] of road-location)

    ; adjust their direction
    set current-direction [direction] of road-location
    if current-direction = "north" [ set heading 0   ]
    if current-direction = "east"  [ set heading 90  ]
    if current-direction = "south" [ set heading 180 ]
    if current-direction = "west"  [ set heading 270 ]

    set at-junction? false
    set has-turned? false
    set is-crossing? false
    set observed? false

    let possible-directions (remove opposite-direction current-direction clockwise)
    set next-direction one-of possible-directions
    set next-intersection next-junction-from road-location current-direction
    set next-turn get-next-turn current-direction next-direction
  ]
end

; main SETUP function
to setup
  clear-all
  set clockwise ["north" "east" "south" "west"]

  draw-map
  create-roads-junctions
  place-cars

  set acceleration 0.2
  set slowdown-overshoot 0.4

  reset-ticks
end

; =========================

; =========================
; RUN + MOVEMENT ON ROADS

; RUN
to go
  ask cars [
    adjust-speed

    ; get the next intersection/JUNCTION
    if next-intersection = nobody [
      let j next-junction-from patch-here current-direction
      if  j != nobody           [ set next-intersection j ]
      if  debug? and j = nobody [ db-car self "NO next-intersection found" ]
    ]

    let ahead1  patch-ahead 1
    let on-road [pcolor = white]  of patch-here
    let at-junc [pcolor = orange] of ahead1

    ;; STOP at JUNCTION
    if on-road and at-junc [
      set speed 0
      snap-center

      if not at-junction? [
        set at-junction? true
      ]
      set arrival-time ticks

      ;; capture the car & its direction BEFORE changing context
      let dir current-direction
      let me  self

      ;; only if next-intersection is a real junction agent
      if is-turtle? next-intersection and [breed] of next-intersection = junctions [
        ask next-intersection [
          if dir = "north" [ set car-S me ]
          if dir = "south" [ set car-N me ]
          if dir = "east"  [ set car-W me ]
          if dir = "west"  [ set car-E me ]
        ]
      ]
    ]

    ;;; GUARD: only move if next patch is a ROAD
    ifelse ahead1 != nobody and [pcolor] of ahead1 = white [
      fd speed
    ] [
      set speed 0
      snap-center
    ]
  ]

  ask junctions [
    handle-junctions-new
  ]
  tick
end

; handling the SPEED of the CAR while on ROAD
to adjust-speed
  ; 1.6 patches forward from the turtle’s position,
  ; 30° wide (centered on its current heading)
  let cars-ahead other cars in-cone 1.6 30

  ; IF other cars are orthogonally placed in front of me, reduce speed
  ifelse any? cars-ahead with [ (heading + [heading] of myself) mod 180 = 90 ] [
    ifelse speed <= slowdown-overshoot [
      set speed 0
    ] [
      set speed speed - slowdown-overshoot
    ]

  ] [
    ; set the speed to match the one of the slowest car in front
    set cars-ahead cars-ahead with [ heading = [heading] of myself ]
    ifelse any? cars-ahead [
      set speed min list speed ([speed] of one-of cars-ahead)
    ] [

      ; if there are no cars ahead, accelerate
      if speed < goal-speed [
        set speed min list (speed + acceleration) goal-speed
      ]
    ]
  ]
end

; =========================

; =========================
; MOVEMENT IN JUNCTIONS

to turn-new
  if next-turn = "left" [
    fd-centered 1
    set heading heading - 45
    set heading heading - 45
    fd-centered 3
  ]

  if next-turn = "right" [
    set heading heading + 45
    set heading heading + 45
    fd-centered 2
  ]

  if next-turn = "straight" [
    fd-centered 3
  ]

  set has-turned? true
end

to continue-turn-new [j c]
  ask c [
    turn-new

    if has-turned? [
      set current-direction next-direction
      set next-direction    one-of remove opposite-direction (current-direction) clockwise
      set next-turn         get-next-turn current-direction next-direction
      set arrival-time      -1
      set next-intersection next-junction-from patch-here current-direction
      set speed             goal-speed
      set observed?         false
      set is-crossing?      false
      set has-turned?       false
    ]
  ]

  ask j [
    ; keep only cars still crossing (those with is-crossing? = true)

  ]
end

to start-turn-new [j c]
  ask j [
    if car-N = c [ set car-N nobody ]
    if car-S = c [ set car-S nobody ]
    if car-E = c [ set car-E nobody ]
    if car-W = c [ set car-W nobody ]
  ]

  ask c [
    fd-centered 2
  ]
end

to first-cross-new [c-w c-n]
  ; get the CARS that arrived EARLIEST at the JUNCTION
  let earliest-arrival min [arrival-time] of c-w
  let earliest-cars    c-w with [ arrival-time = earliest-arrival ]

  ; see which one should have priority, if 2 or more CARS arrived at the SAME TIME
  let filtered-by-left-turn  earliest-cars          with [ not yields-by-left-turn? self earliest-cars ]
  let filtered-by-right-rule filtered-by-left-turn  with [ not loses-right-rule?    self earliest-cars ]

  ; START TURNING, while checking for each set if it is or not empty
  let pick1 one-of filtered-by-right-rule
  ifelse pick1 != nobody [
    set crossing-now (turtle-set c-n pick1)
    start-turn-new self pick1
  ] [
    let pick2 one-of filtered-by-left-turn
    ifelse pick2 != nobody [
      set crossing-now (turtle-set c-n pick2)
      start-turn-new self pick2
    ] [
      let pick3 one-of earliest-cars
      if pick3 != nobody [
        set crossing-now (turtle-set c-n pick3)
        start-turn-new self pick3
      ]
    ]
  ]
end

to handle-junctions-new
  ; create a list of the cars waiting for their turn in the junction
  let cars-waiting no-turtles

  ; put the first cars waiting at the intersection to
  foreach (list car-N car-E car-S car-W) [ c ->
    if c != nobody [
      set cars-waiting (turtle-set cars-waiting c)
      if not [observed?] of c [
        ask c [ set observed? true ]
      ]
    ]
  ]

  ; if there are no cars waiting to enter the intersection, stop
  if not any? cars-waiting [ stop ]

  ifelse count crossing-now = 0 [
    ; if no cars are crossing now, get the first car and start the crossing process
    first-cross-new cars-waiting crossing-now
  ] [
    ; if there are CARS crossing now, CONTINUE TURN
    ask crossing-now [
      continue-turn-new myself self
    ]
  ]

end

;; WHOLE PART COMMENTED OUT
;; =========================

;; =========================
;; (WRONG) MOVEMENT IN JUNCTIONS
;
;to handle-junctions
;  let cars-waiting no-turtles
;
;  foreach (list car-N car-E car-S car-W) [ c ->
;    if c != nobody [
;      set cars-waiting (turtle-set cars-waiting c)
;      if not [observed?] of c [
;        ask c [ set observed? true ]
;      ]
;    ]
;  ]
;
;  if not any? cars-waiting [ stop ]
;
;  ; IF no CARS are crossing now:
;  ifelse count crossing-now = 0 [
;    ; get the CARS that arrived EARLIEST at the JUNCTION
;    let earliest min [arrival-time] of cars-waiting
;    let earliest-cars cars-waiting with [ arrival-time = earliest ]
;
;    ; see which one should have priority, if 2 or more CARS arrived at the SAME TIME
;    let filtered  earliest-cars with [ not yields-by-left-turn? self earliest-cars ]
;    let filtered2 filtered      with [ not loses-right-rule?    self earliest-cars ]
;
;    ; START TURNING
;    let pick one-of filtered2
;    if pick != nobody [
;      set crossing-now (turtle-set crossing-now pick)
;      start-turn self pick
;    ]
;
;  ][
;    ; if there are CARS crossing-now:
;    ; CONTINUE TURN
;    ask crossing-now [
;      continue-turn myself self
;    ]
;
;
;    if count crossing-now = 1 [
;      let pick one-of crossing-now
;
;      let compat cars-waiting with [
;                 not paths-conflict?          approach-of pick [next-turn] of pick approach-of self [next-turn] of self
;                 and not yields-by-left-turn? self crossing-now
;                 and not loses-right-rule?    self crossing-now
;      ]
;
;      if any? compat [
;        let earliest-compat min-one-of compat [arrival-time]
;
;        ; now you can start this car as well:
;        start-turn self earliest-compat
;      ]
;    ]
;
;  ]
;end
;
;to start-turn [j c]
;  ask j [
;    if car-N = c [ set car-N nobody ]
;    if car-S = c [ set car-S nobody ]
;    if car-E = c [ set car-E nobody ]
;    if car-W = c [ set car-W nobody ]
;  ]
;
;  ask c [
;    if next-turn = "left" [set step-turn 5]
;    if next-turn = "right" [ set step-turn 3]
;    if next-turn = "straight" [set step-turn 4]
;  ]
;end
;
;to continue-turn [j c]
;  ask c [
;    if [pcolor] of patch-ahead 1 = orange [
;      if has-turned? or next-turn = "straight" [
;        set current-direction next-direction
;        set next-direction one-of remove opposite-direction (current-direction) clockwise
;        set next-turn get-next-turn current-direction next-direction
;        set arrival-time -1
;        set next-intersection next-junction-from patch-here current-direction
;        set speed goal-speed
;        set observed? false
;        set is-crossing? false
;        set has-turned? false
;      ]
;    ]
;  ]
;
;end
;
;to turn [j c]
;
;  ask j [
;    if car-N = c [ set car-N nobody ]
;    if car-S = c [ set car-S nobody ]
;    if car-E = c [ set car-E nobody ]
;    if car-W = c [ set car-W nobody ]
;  ]
;  ask c [
;    set at-junction? false
;    fd-centered 2
;
;    if next-direction = "north" [
;      if current-direction = "east" [fd-centered 1]
;      set heading 0
;      if current-direction = "north" [fd-centered 3]
;      if current-direction = "east" [fd-centered 3]
;      if current-direction = "west" [fd-centered 2]
;    ]
;
;    if next-direction = "east"  [
;      if current-direction = "south" [fd-centered 1]
;      set heading 90
;      if current-direction = "east" [fd-centered 3]
;      if current-direction = "south" [fd-centered 3]
;      if current-direction = "north" [fd-centered 2]
;    ]
;
;    if next-direction = "south" [
;      if current-direction = "west" [fd-centered 1]
;      set heading 180
;      if current-direction = "south" [fd-centered 3]
;      if current-direction = "west" [fd-centered 3]
;      if current-direction = "east" [fd-centered 2]
;    ]
;
;    if next-direction = "west"  [
;      if current-direction = "north" [fd-centered 1]
;      set heading 270
;      if current-direction = "north" [fd-centered 3]
;      if current-direction = "west" [fd-centered 3]
;      if current-direction = "south" [fd-centered 2]
;    ]
;
;    snap-center
;    set current-direction next-direction
;    set next-direction one-of remove opposite-direction (current-direction) clockwise
;    set next-turn get-next-turn current-direction next-direction
;    set arrival-time -1
;    set next-intersection next-junction-from patch-here current-direction
;    set speed goal-speed
;    db-car self "END CROSS"
;  ]
;end
;
;; geometric CONFLICT approximation for a 4-way single lane JUNCTION
;to-report paths-conflict? [a-approach a-turn b-approach b-turn]
;
;  if a-approach = b-approach [ report true ]
;
;  let opp? (b-approach = opposite a-approach)
;  let adj-right? (b-approach = right-of a-approach)
;  let adj-left?  (a-approach = right-of b-approach)
;
;  if opp? [
;    if (a-turn = "straight" and b-turn = "straight") [ report true ]
;    if (a-turn = "left" and (b-turn = "straight" or b-turn = "right")) [ report true ]
;    if (b-turn = "left" and (a-turn = "straight" or a-turn = "right")) [ report true ]
;
;    report false
;  ]
;
;  if adj-right? or adj-left? [
;    if (a-turn = "straight" and b-turn = "straight") [ report true ]
;    if (a-turn = "right" and b-turn = "straight" and b-approach = right-of a-approach) [ report true ]
;    if (b-turn = "right" and a-turn = "straight" and a-approach = right-of b-approach) [ report true ]
;    if (a-turn = "left" and not (b-turn = "right" and b-approach = right-of a-approach)) [ report true ]
;    if (b-turn = "left" and not (a-turn = "right" and a-approach = right-of b-approach)) [ report true ]
;  ]
;
;  report false
;end
;
;; =========================
; AUXILIARY FUNCTIONS

to-report paths-conflict? [a-approach a-turn b-approach b-turn]

  ; in case the cars are comming from the same direction
  if a-approach = b-approach [ report true ]

  ; separate the rest of the cases
  let opp?       (b-approach = opposite a-approach)
  let app-right? (b-approach = right-of a-approach)
  let app-left?  (a-approach = right-of b-approach)

  ; handle all the cases where the paths intersect
  if opp? [
    if (a-turn = "straight" or a-turn = "right") and b-turn = "left"                             [ report true ]
    if  a-turn = "left"                          and (b-turn = "straight" or b-turn = "right") [ report true ]

    report false
  ]

  if app-left? [
    if (a-turn = "straight" or a-turn = "left") and (b-turn = "straight" or b-turn = "left") [ report true ]
    if  a-turn = "right"                        and  b-turn = "straight"                [ report true ]
  ]

  if app-right? [
    if (b-turn = "straight" or b-turn = "left") and (a-turn = "straight" or a-turn = "left") [ report true ]
    if  b-turn = "right"                         and  a-turn = "straight"               [ report true ]
  ]

  report false
end

; Step exactly one patch and snap to its center
to fd1-centered
  snap-center
  fd 1
  snap-center
end

; Step N patches, snapping at each patch
to fd-centered [n]
  repeat n [fd1-centered]
end

; Hard snap the current turtle to the exact center of its current patch
to snap-center
  move-to patch-here
end

; indicates the type of TURN, based on CURRENT DIRECTION and NEXT DIRECTION
to-report get-next-turn [curr-dir next-dir]
  let i1 position curr-dir clockwise
  let i2 position next-dir clockwise
  let diff (abs (i1 - i2))

  if diff = 0 [ report "straight" ]
  if diff = 1 [ report "right" ]
  if diff = 3 [ report "left" ]
end

to-report next-junction-from [p dir]
  ;; Return the next junction agent in direction `dir` starting from patch `p`.

  let x [pxcor] of p
  let y [pycor] of p

  ;; step vector
  let dist-x 0
  let dist-y 0
  if dir = "north" [ set dist-y  1 ]
  if dir = "south" [ set dist-y -1 ]
  if dir = "east"  [ set dist-x  1 ]
  if dir = "west"  [ set dist-x -1 ]

  ;; if we're already on a junction patch, return that junction
  if [junction-on-patch?] of p [
    report min-one-of junctions [ distance p ]
  ]

  ;; limit steps to one world wrap on the moving axis
  let limit (ifelse-value (dir = "east" or dir = "west") [ world-width ] [ world-height ])

  let steps 0
  while [steps < limit] [
    set x x + dist-x
    set y y + dist-y
    let q patch x y  ;; wraps automatically on torus

    if [junction-on-patch?] of q [
      report min-one-of junctions [ distance q ]
    ]

    set steps steps + 1
  ]

  ;; no junction found along this lane within one wrap
  report nobody
end

; Indicates the SIDE where the CAR stopped, relative to the JUNCTION
; (gives the opposite of the car's movement direction)
to-report approach-of [c]
  ;; 1) preferred: use the car's current-direction if valid
  let d [current-direction] of c
  if member? d ["north" "east" "south" "west"] [
    if d = "north" [ report "S" ]
    if d = "east"  [ report "W" ]
    if d = "south" [ report "N" ]
    if d = "west"  [ report "E" ]
  ]
end

; opposite DIRECTION
; (same as the function above,
; but it works only with north, south, east, west)
to-report opposite-direction [d]
  if d = "north" [report "south"]
  if d = "south" [report "north"]
  if d = "east" [report "west"]
  if d = "west" [report "east"]
end

; opposite DIRECTION
; (same as the function above,
; but it works only with N, S, E, W)
to-report opposite [d]
  if d = "N" [ report "S" ]
  if d = "E" [ report "W" ]
  if d = "S" [ report "N" ]
  if d = "W" [ report "E" ]
end

; direction of OTHER CAR coming from the RIGHT
to-report right-of [d]
  if d = "N" [ report "W" ]
  if d = "E" [ report "N" ]
  if d = "S" [ report "E" ]
  if d = "W" [ report "S" ]
end

; left-turn → YIELDS to the car coming from straight ahead/right
to-report yields-by-left-turn? [c candidates]
  let my-app approach-of c

  ;ISN'Y THIS JUST NEXT-TURN?
  let my-turn get-next-turn ([current-direction] of c) ([next-direction] of c)
  if my-turn != "left" [ report false ]
  report any? candidates with [
    (approach-of self = opposite my-app) and
    (get-next-turn current-direction next-direction = "straight" or get-next-turn current-direction next-direction = "right")
  ]
end

; same-arrival tie → yield to the CAR approaching from the RIGHT
to-report loses-right-rule? [c candidates]
  let my-app approach-of c
  let my-arr [arrival-time] of c
  report any? candidates with [
    [arrival-time] of self = my-arr and approach-of self = right-of my-app
  ]
end

; =========================

; =========================
; DEBUGGING

to db [msg]
  if debug? [ show (word "[" ticks "] " msg) ]
end

to db-car [c msg]
  if debug? [
    let here [patch-here] of c
    show (word "[" ticks "] car#" [who] of c
               " dir=" [current-direction] of c
               " nextDir=" [next-direction] of c
               " atJ=" [at-junction?] of c
               " p=(" [pxcor] of here "," [pycor] of here ") "
               msg)
  ]
end

to db-j [j msg]
  if debug? [
    show (word "[" ticks "] J#" [who] of j
               " lanes=("
               (ifelse-value is-turtle? [car-N] of j [[who] of [car-N] of j] ["-"]) ","
               (ifelse-value is-turtle? [car-E] of j [[who] of [car-E] of j] ["-"]) ","
               (ifelse-value is-turtle? [car-S] of j [[who] of [car-S] of j] ["-"]) ","
               (ifelse-value is-turtle? [car-W] of j [[who] of [car-W] of j] ["-"])
               ") " msg)
  ]
end

; =========================
@#$#@#$#@
GRAPHICS-WINDOW
210
10
828
629
-1
-1
10.0
1
10
1
1
1
0
1
1
1
-30
30
-30
30
1
1
1
ticks
30.0

BUTTON
40
200
103
233
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
113
200
176
233
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
835
11
1669
621
Speed distribution
NIL
NIL
0.0
10.0
0.0
10.0
false
false
"set-plot-x-range 0 1.1\nset-plot-y-range 0 ( number-of-cars )\nset-histogram-num-bars 20" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [speed] of cars"

SLIDER
23
21
195
54
number-of-cars
number-of-cars
0
300
120.0
10
1
NIL
HORIZONTAL

SWITCH
95
310
198
343
debug?
debug?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 0 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 300 165 300 225 300 225 0 180 0
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

car top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 false 210 165 195 165
Line -7500403 false 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
