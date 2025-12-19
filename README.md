# CS152 Final Project — Cost-Aware Warehouse Block Planning (A* in Prolog + Python Viz)

This project models a simplified warehouse robot that must rearrange blocks stored in shelf “slots” across different warehouse locations. The goal is to compute a valid sequence of moves (a plan) from an initial arrangement to a target goal arrangement while respecting an energy budget and minimizing total energy cost.

The planner is implemented in **Prolog using A\*** search, and the **visualization + step-by-step printing** is done in **Python**.

---

## Project Files

### `planner_astar_slots.pl`
This is the main **Prolog planner**.

What it contains:
- **Domain setup**
  - `location/1` (warehouse locations)
  - `position/1` + `shelf_height/2` (shelf levels / heights)
  - `dist/3` (horizontal distances between locations)
  - `weight/2` (block weights)
- **Scenarios**
  - `scenario(ID, StartState, GoalState, Budget).`
- **Legal actions**
  - `successor/4` defines which moves are allowed (move a block from one slot to an empty slot)
- **Cost function**
  - `step_cost/6` defines energy for each move
- **A* Search**
  - `astar/5` and `astar_loop/6` implement A* using `f = g + h`
- **JSON interface for Python**
  - `solve_scenario_json/1` and `solve_scenario_json/2` output results as JSON so Python can read it

### `viz_slots.py`
This is the **Python runner + visualization**.

What it does:
- calls Prolog using `swipl`
- reads the JSON output
- prints:
  - block weights
  - goal state
  - initial state
  - each step (action + step cost breakdown + updated state)
  - total cost recomputed in Python (sanity check)
- creates images for each step in a folder `viz_<scenario_id>/`
  - includes:
    - grid of shelf slots
    - distance labels on the x-axis
    - arrow showing the move path (e.g., `a:1 → c:2`)

---

## State Representation (Important)

A warehouse state is a list of **slots**: