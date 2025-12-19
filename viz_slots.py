import json, os, subprocess
from typing import Dict, List, Any, Optional, Tuple
import matplotlib.pyplot as plt

Action = List[Any]  # Prolog sends moves like: ["move","a",1,"c",2,"b"]

# These must match what I wrote in Prolog (dist/3 facts)
# I use these in Python to recompute + print the cost per step.
DIST = {
    ("a", "b"): 2, ("b", "a"): 2,
    ("a", "c"): 3, ("c", "a"): 3,
    ("b", "c"): 1, ("c", "b"): 1,
}

# Shelf heights (pos 1 is low, pos 3 is high) — same as shelf_height/2 in Prolog
SHELF_HEIGHT = {1: 1, 2: 3, 3: 5}

# Block weights — same as weight/2 in Prolog
WEIGHT = {"a": 1, "b": 2, "c": 3}


def run_prolog(pl_file: str, scenario_id: str, budget: Optional[int] = None) -> dict:
    # Run Prolog and ask it to solve one scenario, then return the JSON result.
    # If budget is None, Prolog will use the default budget from the scenario.
    goal = (
        f"solve_scenario_json({scenario_id})."
        if budget is None
        else f"solve_scenario_json({scenario_id},{budget})."
    )

    cmd = ["swipl", "-q", "-s", pl_file, "-g", goal]
    proc = subprocess.run(cmd, capture_output=True, text=True)

    # If Prolog crashes, I want to see the error clearly.
    if proc.returncode != 0:
        raise RuntimeError(f"Prolog failed.\nSTDERR:\n{proc.stderr}\nSTDOUT:\n{proc.stdout}")

    out = proc.stdout.strip()
    if not out:
        raise RuntimeError("No JSON output from Prolog.")
    return json.loads(out)


def start_slots(sid: str) -> Dict[str, Dict[int, Optional[str]]]:
    # Hardcode the initial state for each scenario (must match Prolog scenario starts).
    # I use None in Python to mean "empty".
    if sid == "s1":
        return {
            "a": {1: "a", 2: "b", 3: None},
            "b": {1: "c", 2: None, 3: None},
            "c": {1: None, 2: None, 3: None},
        }
    if sid == "s2":
        return {
            "a": {1: "c", 2: "b", 3: None},
            "b": {1: "a", 2: None, 3: None},
            "c": {1: None, 2: None, 3: None},
        }
    if sid == "s3":
        return {
            "a": {1: "a", 2: "b", 3: "c"},
            "b": {1: None, 2: None, 3: None},
            "c": {1: None, 2: None, 3: None},
        }
    if sid == "s4":
        return {
            "a": {1: "a", 2: "b", 3: "c"},
            "b": {1: None, 2: None, 3: None},
            "c": {1: None, 2: None, 3: None},
        }

    raise ValueError(f"Unknown scenario: {sid}")


def format_state(slots: Dict[str, Dict[int, Optional[str]]]) -> str:
    # Print state in a clean one-line way (so I can copy into my report if needed).
    parts = []
    for loc in sorted(slots.keys()):
        for pos in sorted(slots[loc].keys()):
            val = slots[loc][pos]
            parts.append(f"{loc}:{pos}={val if val is not None else 'empty'}")
    return "  " + ", ".join(parts)


def format_goal(goal_dict: Dict[str, Any]) -> str:
    # Prolog sends goal like {"a:1":"empty", "c:2":"b", ...}
    keys = sorted(goal_dict.keys(), key=lambda k: (k.split(":")[0], int(k.split(":")[1])))
    parts = [f"{k}={goal_dict[k]}" for k in keys]
    return "  " + ", ".join(parts)


def print_weights() -> None:
    # Quick display of weights so it’s obvious why some moves cost more.
    items = sorted(WEIGHT.items(), key=lambda x: x[0])
    print("Block weights:")
    for b, w in items:
        print(f"  {b}: {w}")


def move_cost(act: Action) -> Tuple[int, Dict[str, int]]:
    # My cost function (same as Prolog):
    # cost = weight * (horizontal_distance + vertical_distance)
    _, sl, sp, dl, dp, block = act
    sp, dp = int(sp), int(dp)

    d = DIST.get((sl, dl), 0)
    v = abs(SHELF_HEIGHT[sp] - SHELF_HEIGHT[dp])
    w = WEIGHT[block]

    return w * (d + v), {"distance": d, "vertical": v, "weight": w}


def apply_move(slots: Dict[str, Dict[int, Optional[str]]], act: Action) -> None:
    # Actually update the Python state after one move.
    _, sl, sp, dl, dp, block = act
    sp, dp = int(sp), int(dp)

    # Sanity checks so I catch bugs early.
    if slots[sl][sp] != block:
        raise ValueError(f"Expected {block} at {sl}:{sp}, found {slots[sl][sp]}")
    if slots[dl][dp] is not None:
        raise ValueError(f"Destination not empty {dl}:{dp}")

    slots[sl][sp] = None
    slots[dl][dp] = block


def draw_grid(slots, step, title, out_dir, current_move=None):
    # Draw the warehouse grid:
    # x-axis = locations (a,b,c)
    # y-axis = shelf positions (1,2,3)
    locs = sorted(slots)
    pos_ids = sorted(next(iter(slots.values())))
    cell_w, cell_h = 1.0, 1.0

    fig, ax = plt.subplots()

    # Draw boxes (one cell = one shelf slot). If a block is there, draw its label.
    for xi, loc in enumerate(locs):
        for yi, p in enumerate(pos_ids):
            ax.add_patch(plt.Rectangle((xi * cell_w, yi * cell_h), cell_w, cell_h, fill=False))
            b = slots[loc][p]
            if b is not None:
                ax.text(xi + 0.5, yi + 0.5, b, ha="center", va="center", fontsize=16)

        # Location label under each column
        ax.text(xi + 0.5, -0.6, loc, ha="center", va="center", fontsize=12, fontweight="bold")

    # Shelf position labels on the left
    for yi, p in enumerate(pos_ids):
        ax.text(-0.3, yi + 0.5, f"pos {p}", ha="right", va="center", fontsize=10)

    # Show distances between adjacent locations (so the cost makes sense visually)
    for i in range(len(locs) - 1):
        d = DIST.get((locs[i], locs[i + 1]), "?")
        ax.text(i + 0.5, -1.05, f"dist={d}", ha="center", va="center", fontsize=10, color="gray")
        ax.plot([i + 1.0, i + 1.0], [-0.95, -0.85], color="gray", linewidth=1)

    # If we are in a step, draw an arrow showing the move path (like a → c)
    if current_move:
        _, sl, sp, dl, dp, block = current_move
        x1, x2 = locs.index(sl) + 0.5, locs.index(dl) + 0.5
        y = -1.35
        ax.annotate("", xy=(x2, y), xytext=(x1, y), arrowprops=dict(arrowstyle="->", linewidth=2))
        ax.text(
            (x1 + x2) / 2,
            y - 0.15,
            f"{sl}:{sp} → {dl}:{dp} (block={block})",
            ha="center",
            va="top",
            fontsize=10,
        )

    ax.set_xlim(-0.8, len(locs) + 0.2)
    ax.set_ylim(-1.8, len(pos_ids) + 0.2)
    ax.set_title(f"{title} — step {step}")
    ax.axis("off")

    os.makedirs(out_dir, exist_ok=True)
    plt.savefig(os.path.join(out_dir, f"step_{step:02d}.png"), bbox_inches="tight")
    plt.close(fig)


def visualize(pl_file: str, sid: str, budget: Optional[int] = None) -> None:
    # Run Prolog, then print + draw everything step-by-step.
    res = run_prolog(pl_file, sid, budget)

    print(f"\n=== Scenario {sid} ===")
    print_weights()

    goal_dict = res.get("goal", {})
    if goal_dict:
        print("Goal state:")
        print(format_goal(goal_dict))

    # If Prolog says “no plan”, just print it and stop.
    if not res.get("ok"):
        print("No plan found:", res)
        return

    plan: List[Action] = res["plan"]
    total_cost_from_prolog = res["cost"]

    print(f"Budget: {res['budget']}")
    print(f"Plan steps: {len(plan)}")
    print(f"Total cost (Prolog): {total_cost_from_prolog}")

    slots = start_slots(sid)
    print("\nInitial state:")
    print(format_state(slots))

    title = f"{sid} (cost={total_cost_from_prolog}, budget={res['budget']})"
    out_dir = f"viz_{sid}"
    draw_grid(slots, step=0, title=title, out_dir=out_dir)

    running_cost = 0
    for i, act in enumerate(plan, start=1):
        c, br = move_cost(act)
        running_cost += c

        print(f"\nStep {i}: {act}")
        print(
            f"  step_cost = weight({br['weight']}) * "
            f"(distance({br['distance']}) + vertical({br['vertical']})) = {c}"
        )

        apply_move(slots, act)

        print("  state:")
        print(format_state(slots))

        draw_grid(slots, step=i, title=title, out_dir=out_dir, current_move=act)

    print(f"\nTotal cost (Python recompute): {running_cost}")
    print(f"Images saved in: {out_dir}/")


if __name__ == "__main__":
    PROLOG_FILE = "planner_astar_slots.pl"
    for sid in ["s1", "s2", "s3", "s4"]:
        visualize(PROLOG_FILE, sid)
