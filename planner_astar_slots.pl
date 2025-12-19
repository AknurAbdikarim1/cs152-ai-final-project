:- use_module(library(lists)).
:- use_module(library(http/json)).

% ---------------- Domain setup ----------------
% I have 3 warehouse locations (a,b,c) and 3 shelf heights (pos 1..3).
location(a). location(b). location(c).
position(1). position(2). position(3).

% Distances between locations (used in the move cost).
dist(a,b,2). dist(b,a,2).
dist(a,c,3). dist(c,a,3).
dist(b,c,1). dist(c,b,1).

% Each block has a weight (heavier = more expensive to move).
weight(a,1). weight(b,2). weight(c,3).

% Shelf heights: pos 1 is low, pos 3 is high.
shelf_height(1, 1).
shelf_height(2, 3).
shelf_height(3, 5).


% ---------------- Scenarios ----------------
% A "state" is a list of slots.
% slot(Location, Position, empty | has(Block))

scenario(s1,
  state([
    slot(a,1,has(a)), slot(a,2,has(b)),
    slot(b,1,has(c)), slot(b,2,empty),
    slot(c,1,empty),  slot(c,2,empty)
  ]),
  state([
    slot(a,1,empty),  slot(a,2,empty),
    slot(b,1,has(a)), slot(b,2,empty),
    slot(c,1,has(c)), slot(c,2,has(b))
  ]),
  40).

scenario(s2,
  state([
    slot(a,1,has(c)), slot(a,2,has(b)),
    slot(b,1,has(a)), slot(b,2,empty),
    slot(c,1,empty),  slot(c,2,empty)
  ]),
  state([
    slot(a,1,empty),  slot(a,2,empty),
    slot(b,1,has(a)), slot(b,2,has(b)),
    slot(c,1,has(c)), slot(c,2,empty)
  ]),
  40).

% s3: everything starts stacked vertically at location a (a at bottom, c on top)
scenario(s3,
  state([
    slot(a,1,has(a)),
    slot(a,2,has(b)),
    slot(a,3,has(c)),
    slot(b,1,empty), slot(b,2,empty), slot(b,3,empty),
    slot(c,1,empty), slot(c,2,empty), slot(c,3,empty)
  ]),
  state([
    slot(a,1,empty), slot(a,2,empty), slot(a,3,empty),
    slot(b,1,has(a)), slot(b,2,empty), slot(b,3,empty),
    slot(c,1,has(c)), slot(c,2,has(b)), slot(c,3,empty)
  ]),
  100).

% s4: same as s3 but I set the budget super low so it should fail
scenario(s4,
  state([
    slot(a,1,has(a)),
    slot(a,2,has(b)),
    slot(a,3,has(c)),
    slot(b,1,empty), slot(b,2,empty), slot(b,3,empty),
    slot(c,1,empty), slot(c,2,empty), slot(c,3,empty)
  ]),
  state([
    slot(a,1,empty), slot(a,2,empty), slot(a,3,empty),
    slot(b,1,has(a)), slot(b,2,empty), slot(b,3,empty),
    slot(c,1,has(c)), slot(c,2,has(b)), slot(c,3,empty)
  ]),
  3).   % intentionally impossible


% ---------------- Helper predicates ----------------
% Quick lists of locations/positions (so I don not hardcode loops)
all_locations(Locs) :- findall(L, location(L), Ls), sort(Ls, Locs).
all_positions(Pos)  :- findall(P, position(P), Ps), sort(Ps, Pos).

% Keep states consistent (order does not matter, so I sort the slots)
normalize_state(state(Slots), state(Sorted)) :-
  sort(Slots, Sorted).

% Read a slot value at (Location, Position)
get_slot(state(Slots), L, P, Val) :-
  member(slot(L,P,Val), Slots).

% Update one slot (Location, Position) to a new value
set_slot(state(Slots), L, P, NewVal, state(NewSlots)) :-
  select(slot(L,P,_Old), Slots, slot(L,P,NewVal), NewSlots).


% ---------------- Cost function ----------------
% My move cost:
% cost = weight * (horizontal distance + vertical distance)
step_cost(SL, SP, DL, DP, Block, Cost) :-
  dist(SL, DL, D),
  shelf_height(SP, HS),
  shelf_height(DP, HD),
  Vertical is abs(HS - HD),
  weight(Block, W),
  Cost is W * (D + Vertical).


% ---------------- Legal actions / successors ----------------
% One move means: take a block from (SL,SP) and put it in empty (DL,DP)
% move(SrcLoc,SrcPos,DstLoc,DstPos,Block)
successor(State, move(SL,SP,DL,DP,Block), NextState, StepCost) :-
  all_locations(Locs), all_positions(Pos),
  member(SL, Locs), member(DL, Locs),
  member(SP, Pos),  member(DP, Pos),
  (SL \= DL ; SP \= DP),

  get_slot(State, SL, SP, has(Block)),   % source must have a block
  get_slot(State, DL, DP, empty),        % destination must be empty

  set_slot(State, SL, SP, empty, Tmp),
  set_slot(Tmp,   DL, DP, has(Block), RawNext),
  normalize_state(RawNext, NextState),

  step_cost(SL,SP,DL,DP,Block, StepCost).


% ---------------- Heuristic ----------------
% Simple heuristic: count how many blocks are not already in their goal slots.
% (Each misplaced block needs at least one move.)
heuristic(State, Goal, H) :-
  findall(1, misplaced(State, Goal), Ms),
  length(Ms, H).

misplaced(state(Slots), Goal) :-
  member(slot(L,P,has(B)), Slots),
  \+ goal_has(Goal, L, P, B).

goal_has(state(Slots), L, P, B) :-
  member(slot(L,P,has(B)), Slots).


% ---------------- A* search ----------------
% A* keeps a frontier ordered by f = g + h
% g = cost so far, h = heuristic
astar(Start0, Goal0, Budget, Plan, Cost) :-
  normalize_state(Start0, Start),
  normalize_state(Goal0, Goal),
  heuristic(Start, Goal, H0),
  G0 = 0,
  F0 is G0 + H0,
  StartNode = node(Start, G0, F0, []),
  astar_loop([ (F0-G0-0)-StartNode ], Goal, Budget, [], Plan, Cost).

astar_loop(Frontier, Goal, Budget, Closed, Plan, Cost) :-
  Frontier \= [],
  Frontier = [_-node(State,G,_,ActionsRev) | Rest],
  ( State == Goal ->
      reverse(ActionsRev, Plan),
      Cost = G
  ;
    ( member(closed(State,BestG), Closed), BestG =< G ->
        astar_loop(Rest, Goal, Budget, Closed, Plan, Cost)
    ;
      update_closed(State, G, Closed, Closed1),

      % Expand this state: generate children, compute new g/f, prune if over budget
      findall(Key-node(NS,G2,F2,[Act|ActionsRev]),
        ( successor(State, Act, NS, Step),
          G2 is G + Step,
          G2 =< Budget,
          heuristic(NS, Goal, H2),
          F2 is G2 + H2,
          Key = (F2-G2-1)
        ),
        Children),

      append(Rest, Children, Unsorted),
      sort(Unsorted, Sorted),            % this is my priority queue (lowest f first)
      astar_loop(Sorted, Goal, Budget, Closed1, Plan, Cost)
    )
  ).

% Closed list: keep best g we have seen for each state
update_closed(State, G, Closed, Out) :-
  ( select(closed(State,OldG), Closed, Rest) ->
      ( G < OldG -> Out = [closed(State,G)|Rest]
      ; Out = [closed(State,OldG)|Rest] )
  ; Out = [closed(State,G)|Closed] ).


% ---------------- JSON output for Python ----------------
% Convert Prolog move(...) into a Python-friendly list
action_to_json(move(SL,SP,DL,DP,B), ["move", SL, SP, DL, DP, B]).

% Main entry: solve a scenario and print JSON so Python can read it
solve_scenario_json(ScenarioId, Budget) :-
  scenario(ScenarioId, Start, Goal, _Def),
  goal_to_pairs(Goal, GoalPairs),

  ( astar(Start, Goal, Budget, Plan, Cost) ->
      maplist(action_to_json, Plan, PlanJSON),
      dict_pairs(GoalDict, goal, GoalPairs),
      Result = _{ok:true, scenario:ScenarioId, budget:Budget, cost:Cost, plan:PlanJSON, goal:GoalDict},
      json_write_dict(current_output, Result), nl
  ;   dict_pairs(GoalDict, goal, GoalPairs),
      Result = _{ok:false, scenario:ScenarioId, budget:Budget, error:"no_plan_within_budget", goal:GoalDict},
      json_write_dict(current_output, Result), nl
  ),
  halt.

% Convenience: if Python calls solve_scenario_json(s1). use the scenario default budget
solve_scenario_json(ScenarioId) :-
  scenario(ScenarioId, _Start, _Goal, DefaultBudget),
  solve_scenario_json(ScenarioId, DefaultBudget).


% ---------------- Goal state formatting (for printing in Python) ----------------
% Convert goal state into dict pairs like: "a:1"="empty", "c:2"="b", etc.
slot_key(L,P,Key) :- format(atom(Key), "~w:~w", [L,P]).

slot_val_json(empty, "empty").
slot_val_json(has(B), B).

goal_to_pairs(state(Slots), Pairs) :-
  findall(Key-Val,
    ( member(slot(L,P,V), Slots),
      slot_key(L,P,Key),
      slot_val_json(V, Val)
    ), Pairs).