# Workout Planner DSL

This is a **Domain-Specific Language (DSL)** for planning and tracking workouts.  
The domain includes **workouts** and **exercises**, and supports hierarchical workouts (workouts containing sub-workouts).

---

## Domain Description

**Entities:**
- **Workout**: a collection of exercises or other sub-workouts.
- **Exercise**: defined by a name, number of sets, repetitions, and optional weight.
- **Commands**: operations on workouts and exercises, like creating, adding, removing, starting a workout, and viewing examples.

**Operations:**
- `create workout <name>`: create a new workout.
- `add exercise <exercise> <sets> <reps> [<weight>] to <workout>`: add an exercise to a workout.
- `add subworkout <subworkout> to <workout>`: add a nested workout to a workout.
- `remove exercise <exercise> from <workout>`: remove an exercise.
- `start <workout>`: begin a workout.
- `dump examples`: show example commands.

**Recursive element:**  
- Workouts can contain **sub-workouts**, which can themselves contain exercises or other sub-workouts.

---

## BNF Grammar

BNF (Backus-Naur Form) is a **formal way to describe the syntax** of your DSL commands.

```bnf
<command> ::= "create workout" <workout_name>
            | "add exercise" <exercise_name> <sets> <reps> [<weight>] "to" <workout_name>
            | "add subworkout" <subworkout_name> "to" <workout_name>
            | "remove exercise" <exercise_name> "from" <workout_name>
            | "start" <workout_name>
            | "dump examples"

<workout_name> ::= <string>
<exercise_name> ::= <string>
<sets> ::= <integer>
<reps> ::= <integer>
<weight> ::= <integer>
<string> ::= sequence of letters, numbers, and spaces
<integer> ::= 0 | 1 | 2 | ...


---

## Examples

create workout "Morning Routine"
add exercise "Push-ups" 3 15 to "Morning Routine"
add exercise "Squats" 3 20 to "Morning Routine"
create workout "Upper Body Blast"
add subworkout "Upper Body Blast" to "Morning Routine"
