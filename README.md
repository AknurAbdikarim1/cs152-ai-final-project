# CS152 Final Project  
## Cost-Aware Warehouse Block Planning (A* in Prolog + Python Visualization)

This project models a simplified warehouse planning problem. A robot must move blocks between warehouse locations and shelf heights to reach a target configuration while staying within an energy budget and minimizing total energy cost.

The planning logic is implemented in **Prolog using A\*** search, and the results are **visualized step-by-step in Python**.

---

## Repository Structure

### `planner_astar_slots.pl`
This file contains **all of the AI logic**.

What is inside and why:

- **Domain definitions**
  - `location/1`, `position/1`  
    Define warehouse locations and shelf levels.
  - `dist/3`  
    Horizontal distances between locations (used for cost).
  - `shelf_height/2`  
    Physical height of each shelf position.
  - `weight/2`  
    Weight of each block (heavier blocks cost more to move).

- **Scenario definitions**
  - `scenario(ID, StartState, GoalState, Budget).`
  - Each scenario defines:
    - the initial warehouse configuration
    - the goal configuration
    - the energy budget

- **Action model**
  - `successor/4` defines which moves are legal:
    - move one block
    - from a non-empty slot
    - to an empty slot

- **Cost function**
  - `step_cost/6`
  - Energy cost is:
    ```
    cost = block_weight * (horizontal_distance + vertical_distance)
    ```

- **Heuristic**
  - Counts how many blocks are not yet in their goal slots.
  - This guides A* without overestimating cost.

- **A* search implementation**
  - `astar/5` and `astar_loop/6`
  - Uses `f = g + h`
  - Prunes paths that exceed the budget.

- **JSON interface**
  - `solve_scenario_json/1` and `/2`
  - Outputs results as JSON so Python can read them.

This file is responsible for **finding optimal plans** (or determining that no plan exists within the budget).

---

### `viz_slots.py`
This file handles **running the planner and visualizing results**.

What is inside and why:

- Calls **SWI-Prolog** from Python using `subprocess`
- Parses the JSON output from Prolog
- Prints:
  - block weights
  - goal state
  - initial state
  - each action step
  - cost breakdown per move
  - final total cost (recomputed in Python as a sanity check)
- Generates **visualizations**:
  - warehouse grid (locations × shelf heights)
  - distance labels between locations
  - arrows showing each move path
- Saves images into folders like:
viz_s1/
viz_s2/
viz_s3/
viz_s4/


---

## Test Scenarios

All test scenarios are defined in **`planner_astar_slots.pl`**, and their visual outputs are saved in the repository.

### Scenario `s1`
- Simple rearrangement
- Budget is sufficient
- Produces a valid plan

### Scenario `s2`
- Different initial configuration
- Budget is sufficient
- Produces a valid plan

### Scenario `s3` (stacked case)
- All blocks start stacked vertically at one location
- Requires both vertical and horizontal movement
- Demonstrates effect of block weight and shelf height
- Budget is sufficient

### Scenario `s4` (budget failure case)
- Same setup as `s3`
- Budget is intentionally too low
- Planner correctly reports that no plan exists

Each scenario has a corresponding visualization folder in the repository (`viz_s1`, `viz_s2`, etc.), showing the step-by-step execution.

---

## How to Run the Project

### Requirements
- **SWI-Prolog** (`swipl` must be available in the terminal)
- **Python 3**
- `matplotlib` for visualization

Install matplotlib if needed:
```bash
pip3 install matplotlib
