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

---
## State Persistence

When we open up the program it works fine and all, but when our program is workout planer whats the point if we can use it only one time and our all programs are just deleted. Yes we can leave it open, but it will eat out memory. So that is why we use `storage.txt` to save our user information, using state and IO operations.

### How it Works:

A common problem is that when we write to file, we have to do it on separate threads so our program won't start lagging or multiple blocks of information would just mess up our storage. Main things ensuring our programs best working capability:

* **Asynchronous I/O via STM and Chans:** Rather then doing everything on main thread, all Input Output operations going through a dedicated storage thread. This storage thread makes our program life easier, so the main thread never waits on disk access.
* **Loading (`load`):** When the app starts, it reads `storage.txt`, parses each DSL command, and applies them in sequence to our empty state. This restores out written previous data.
* **Saving (`save`):** Whenever the user writes something (exacutes some kind of command), the app reads input and that input (which is serialized) is handed off to the mentioned storage thread, which writes that input to the file.

### Serialization:

Thinking about all our commands we do not need to save everything. For example why do we need to save remove and select which is only temporary commands.
So this table shows commands which we store and not.

| State Element | Serialized Command | Why? |
| :--- | :--- | :--- |
| **Workout Hierarchy** | `create workout "<name>" { <content> }` | Every workout (including sub-workouts) is nested in `create workout` block. |
| **Exercises** | `add exercise "<n>" <sets> <reps> <weight>kg` | Each exercise becomes its own command, written in the specific workout block (Where user added it). |
| **Modification Commands** (`select`, `remove`, etc.) | **Excluded** | These commands are temporary so it is usless to save them. |
| **`currentWorkoutName`** | **Ignored** | This only saves in state to know which Workout is now editing |

---

### Some Examples

Let’s look at what actually gets saved in `storage.txt`.

#### Example A:

Imagine a user who’s set up two main workouts, “Morning” and “Evening.” The “Evening” workout even features a sub-workout, “Warmup,” demonstrating nested hierarchies.

| Workout Name | Exercises | Sub-Workouts |
| :--- | :--- | :--- |
| **Morning** | Push-ups (3x15) | None |
| **Evening** | None | Warmup |
| **Warmup** | Stretching (1x10, 0kg) | None |

**What gets saved:**

```
create workout "Morning" { add exercise "Push-ups" 3 15 }
create workout "Evening" { create workout "Warmup" { add exercise "Stretching" 1 10 0kg } }
```

These get saved and when user opens progam the second time, he can use show workout "workout name" and will show all the excersises and sub-workouts.

---

#### Example B: After Modifications

Consider a session where the user:

1. Creates “Plan A” with a “Biceps” exercise.
2. Deletes “Biceps.”
3. Adds a “Triceps” exercise.

The only thing that ends up saved is the final, meaningful information: “Triceps” under “Plan A.”.

| Workout Name | Final Exercises | Sub-Workouts |
| :--- | :--- | :--- |
| **Plan A** | Triceps (3x10, 50kg) | None |

**What gets saved:**

```
create workout "Plan A" { add exercise "Triceps" 3 10 50kg }
```

User only gets the final workout structure.

*No trace of the deleted “Biceps” exercise, because it is temporary.*

---

### Example Walkthrough: Simple Persistence

Step 1 & 2: Start the app, create workouts (check storage.txt file).

![Screenshot: app launched and workouts created](screenshots/Screen1.png)

![Screenshot: what storage.txt looks like now](screenshots/Screen2.png)

Step 3: Quit the app.

![Screenshot: app exiting](screenshots/Screen3.png)

Step 4 & 5: Open the app and all the information still there, just as you left it. (Here show workout is used to show that workouts are saved)

![Screenshot: app relaunching, state restored](screenshots/Screen4.png)

---
