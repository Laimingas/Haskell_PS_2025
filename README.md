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
            | "add exercise" <exercise_name> <sets> "x" <reps> "to" <workout_name>
            | "add exercise" <exercise_name> <sets> "x" <reps> <weight> "to" <workout_name>
            | "add subworkout" <subworkout_name> "to" <workout_name>
            | "remove exercise" <exercise_name> "from" <workout_name>
            | "start" <workout_name>
            | "stop" <workout_name>
            | "dump examples"

<workout_name>    ::= <quoted_string>
<subworkout_name> ::= <quoted_string>
<exercise_name>   ::= <quoted_string>

<quoted_string> ::= "\"" <chars> "\""

<chars> ::= <char> | <char> <chars>
<char>  ::= "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j"
          | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t"
          | "u" | "v" | "w" | "x" | "y" | "z"
          | "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
          | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T"
          | "U" | "V" | "W" | "X" | "Y" | "Z"
          | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
          | " " | "-" | "_"

<sets>   ::= <integer>
<reps>   ::= <integer>
<weight> ::= <integer> "kg"

<integer> ::= <digit> | <digit> <integer>
<digit>   ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
```

---

## Examples

create workout "Morning Routine"
add exercise "Push-ups" 3 15 to "Morning Routine"
add exercise "Squats" 3 20 to "Morning Routine"
create workout "Upper Body Blast"
add subworkout "Upper Body Blast" to "Morning Routine"
