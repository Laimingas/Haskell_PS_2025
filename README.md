# Workout Planner DSL

This is a **Domain-Specific Language (DSL)** for planning and tracking workouts.  
The domain includes **workouts** and **exercises**, and supports hierarchical workouts (workouts containing sub-workouts).

---

## Domain Description

**Entities:**
- **Workout**: a collection of exercises or other sub-workouts.
- **Exercise**: defined by a name, number of sets, repetitions, and/or optional weight.

**Operations:**
- `create workout <name> { ... }`: create a new workout with nested exercises or sub-workouts.
- `add exercise <exercise> <sets> <reps>`: add an exercise to a workout without weight.
- `add exercise <exercise> <sets> <reps> <weight>`: add an exercise to a workout with weight.
- `remove exercise <exercise>`: remove an exercise.
- `start <workout>`: begin a workout.
- `stop <workout>`: stop workout.
- `show all workouts`: list all workouts.
- `show workout <workout>`: show a specific workout and its contents.
- `select workout <name> { ... }`: select an existing workout and apply nested operations.
- `dump examples`: show example commands.

**Recursive element:**  
- `create workout` allows **recursive nesting of workouts and commands**.


---

## Examples
```haskell
create workout "Morning Routine" 
{
    add exercise "Push-ups" 3 15
    add exercise "Squats" 3 20
    create workout "Upper Body Blast" 
    {
        add exercise "Bench Press" 3 10 50
        add exercise "Pull-ups" 3 8 0
    }
}
select workout "Morning Routine" 
{
    add exercise "Deadlift" 5 5 100
    remove exercise "Push-ups"
    create workout "Leg Day" 
    {
        add exercise "Lunges" 3 12
    }
}
show all workouts
show workout "Morning Routine"
start "Morning Routine"
stop "Morning Routine"
dump examples
```
---

## BNF Grammar

BNF (Backus-Naur Form) is a **formal way to describe the syntax** of your DSL commands.

```bnf
<command> ::= "create workout" <workout_name> "{" <command_list> "}"
            | "add exercise" <exercise_name> <sets> <reps>
            | "add exercise" <exercise_name> <sets> <reps> <weight>
            | "remove exercise" <exercise_name>
            | "start" <workout_name>
            | "stop" <workout_name>
            | "show all workouts"
            | "show workout" <workout_name>
            | "select workout" <workout_name> "{" <command_list> "}"
            | "dump examples"

<command_list> ::= <command> | <command> <command_list>

<workout_name>    ::= <quoted_string>
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

