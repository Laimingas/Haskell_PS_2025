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

The program is stateful and persistent. State persistence is managed through an asynchronous thread (`storageOpLoop`), which handles all file I/O operations (`storage.txt`) via a channel (`Chan StorageOp`).

### Implementation Details:

State persistence is managed concurrently using **Software Transactional Memory (STM)** for the `State` container and **Channels (`Chan StorageOp`)** for file I/O operations.

* **Asynchronicity:** File I/O operations (`readFile`, `writeFile`) are delegated to a dedicated **storage thread** (`storageOpLoop`) via the channel, ensuring the main application remains responsive.
* **Loading (`load`):** The entire content of `storage.txt` is read, parsed using the DSL parser (`many parseCommand`), and the resulting list of commands is applied sequentially to an empty state, effectively restoring the program's condition.
* **Saving (`save`):** The program state is first **serialized** into a string of commands and then securely passed to the storage thread for atomic writing to the file.


### Serialization Strategy

The key to efficient persistence is ensuring the saved commands reconstruct the final state from scratch, without relying on modification commands (`select workout`, `remove exercise`).

The serialization strategy is designed for **idempotent reconstruction**; we only save the commands necessary to create the final structure, ignoring transient session data and modification commands.

The serialization strategy is designed for **idempotent reconstruction**; we only save the commands necessary to create the final structure, ignoring transient session data and modification commands.

| State Element | Generated Command(s) | Rationale |
| :--- | :--- | :--- |
| **`Workout`** (Hierarchy) | `create workout "<name>" { <content> }` | Each workout, including its nested `subWorkouts` and `exercises`, is generated as a single, fully **nested `create workout` block**. This ensures the entire hierarchy can be reconstructed reliably from an empty starting point. |
| **`Excercise`** | `add exercise "<n>" <s> <r>` or `add exercise "<n>" <s> <r> <w>kg` | Exercises are directly mapped to their corresponding `add exercise` commands and placed within the enclosing `{...}` block. |
| **Modification Commands** |  `select workout`, `remove exercise` | Commands that modify existing state are **not serialized**. Only the **final structure** (e.g., the exercises that remain after removal) is recorded. This prevents redundant or conflicting operations during state restoration. |
| **`currentWorkoutName`** | **Ignored** | This field is not part of the persistent data model and is never serialized to storage.txt. Consequently, it is always reset to Nothing upon program restart, requiring the user to explicitly use a command like select workout to set the context again. |
---
### 3. Serialization Examples 

The serialization process ensures that the generated command list cleanly and rebuilds the final state.

#### Example A: Simple Hierarchy

**Actual State Stored in Memory (`State`):**
A state containing two main workouts: "Morning" and "Evening", where "Evening" contains a sub-workout "Warmup".

| Workout Name | Exercises | Sub-Workouts |
| :--- | :--- | :--- |
| **Morning** | Push-ups (3x15) | None |
| **Evening** | None | Warmup |
| **Warmup** | Stretching (1x10, 0kg) | None |

**Generated `storage.txt` Content (Used for Restoration):**
create workout "Morning" { add exercise "Push-ups" 3 15 } create workout "Evening" { create workout "Warmup" { add exercise "Stretching" 1 10 0kg } }


---

#### Example B: Post-Modification State (Efficiency)

This demonstrates that **modification commands** (`select workout`, `remove exercise`) are **omitted** as they do not define the final structure.

**User Executed Commands (Session History):**
1. `create workout "Plan A" { add exercise "Biceps" 3 10 }`
2. `select workout "Plan A" { remove exercise "Biceps" }`
3. `add exercise "Triceps" 3 10 50kg`

**Actual Final State in Memory (`State`):**
The final state only contains the "Triceps" exercise.

| Workout Name | Final Exercises | Sub-Workouts |
| :--- | :--- | :--- |
| **Plan A** | Triceps (3x10, 50kg) | None |

**Generated `storage.txt` Content (Minimal and Clean):**
create workout "Plan A" { add exercise "Triceps" 3 10 50kg }

*Note: The commands from steps 1 and 2 are effectively replaced by step 3 in the final persistent state.*

---


### Example: Simple Workout Persistence

Step 1 & 2: Launch and State Modification

![Program was launched and two workouts were created.](screenshots/Screen1.png)

![Storage.txt](screenshots/Screen2.png)

Step 3: Exit Program

![Screenshot showing program exiting](screenshots/Screen3.png)

Step 4 & 5: Relaunch and State Restoration

![Screenshot showing program relaunch](screenshots/Screen4.png)

