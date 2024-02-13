# QiskitBlocks
Teaches quantum computing and Qiskit in a Minetest block world. 
- Here are the [Quantum Computing Workshop with QiskitBlocks web-based slides](https://slides.com/javafxpert/qiskitblocks).
- Watch a [video that gives a gentle introduction to quantum computing using cats and QiskitBlocks](https://www.youtube.com/watch?v=tIDmnmJscXE)

Please choose one of the *Installing and running* options below and follow the instructions.

## Installing and running (the quick and easy way using the Minetest Content Database)

To get started with Minetest and explore the Qiskit Blocks, follow these steps to download and install Minetest on your computer:

- **For Windows users:** Download Minetest 5.2 by clicking on the following link. This will initiate the download of the zip file directly to your computer.
  - [Download Minetest 5.2 Windows](https://github.com/JavaFXpert/QiskitBlocks/blob/master/minetest/minetest-5.2.0-win64.zip)

- **For Mac users:** Download Minetest 5.2 for Mac through the link below. Your download should begin immediately upon clicking.
  - [Download Minetest 5.2 Mac](https://github.com/JavaFXpert/QiskitBlocks/blob/master/minetest/minetest-5.2.0-dev-10.11.6-osx.zip)

- After downloading the zip file, extract its contents to a preferred location on your computer. Then, run the Minetest executable.
  
- Click the `Content` tab shown here, then click the `Browse online content` button. 
![Minetest Content Tab](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_content_tab.png)

- When on the page shown here, type `QiskitBlocks`, click the `Search` button, and click the `Install` button beside the `QiskitBlocks` row. Click the `Back to Main Menu` button when installation has completed.
![Minetest Search QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_search_qiskitblocks.png)

- For QiskitBlocks to work correctly, HTTP requests must be allowed for one of its core components. To do this, go to the `Settings` menu. Click on `All Settings`.
![Minetest Settings Tab](https://user-images.githubusercontent.com/6960065/116815046-09853d80-ab5c-11eb-8748-9f40171ea35c.png)

- First enter `HTTP mods` into the search bar and then click the `Search` button. Select the row containing `HTTP mods` and click on the `Edit` button.
![Minetest All Settings](https://user-images.githubusercontent.com/6960065/116815053-130ea580-ab5c-11eb-9a60-d8f30e65e6f8.png)

- Enter `q_command` and click the `Save` button.
![Minetest HTTP Mods Setting Dialog](https://user-images.githubusercontent.com/6960065/116815070-215cc180-ab5c-11eb-97e5-67e61950f9c6.png)

- Leave the `All Settings` menu by clicking on the `Back to Settings page` button.
![Minetest All Settings Exit](https://user-images.githubusercontent.com/6960065/116815076-2588df00-ab5c-11eb-8077-ee9262aa5fd2.png)

- Although Minetest typically uses your computer's default language, you must select a language in Minetest for QiskitBlocks messages to be displayed in your desired language. Currently, QiskitBlocks messages have been translated to Japanese, so please refer to the [Selecting a language](https://github.com/JavaFXpert/QiskitBlocks#selecting-a-language) section below for instructions.

- Click the `Start Game` tab shown here, select the round `QiskitBlocks` game from the lower left, deselect the three checkboxes, and click the `New` button.
![Minetest Start Game QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_startgame_qiskitblocks.png)

- From the *new world* dialog shown here, make up a world name with characters and underscores, enter `0` in the `Seed` field, select `singlenode` or `flat` in the `Mapgen` field, and click the `Create` button.
![Minetest New World Dialog](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_newworld_qiskitblocks.png)

- Click the `Play Game` button, waiting a few seconds while the new world is generated and lighted.

## Selecting a language
Due to the great translation work of [Kifumi Numata](https://twitter.com/kifuminumata) , you may choose for QiskitBlocks messages to be displayed in Japanese (`ja`). To accomplish this, take the following steps: 

- From the `Settings` tab, click the `All Settings` button:
![Minetest All Settings](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_all_settings_button.png)

- Click `Client and Server` to expand it, then click `language`. Click the edit button, select `ja` from the dropdown list, and click the `Save` button. After clicking the `< Back to Settings page` button, exit Minetest and run it again so that your language selection takes effect in QiskitBlocks messages:  
![Minetest select language](https://github.com/JavaFXpert/QiskitBlocks/raw/master/minetest_select_language.png)

## Explore and learn!
- When you're in the starting room with all of the quantum operation blocks on the wall, use the W, A, S, D keys to walk up to the sign on the right side of the door. Right-click the sign and follow the instructions. Have fun exploring and solving quantum circuit puzzles! 

Please reach out to James Weaver on Qiskit Slack (located at [qiskit.org](http://qiskit.org)) with questions or feedback.

![QiskitBlocks escape rooms](https://github.com/JavaFXpert/QiskitBlocks/raw/master/escape_room_psi_minus.png)

![Portal Room in QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/qiskitblocks_portal_room.png)

![Quantum Blocks Academy in QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/quantum_blocks_academy.png)

![Quantum Circuits Garden in QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/quantum_circuits_garden.png)

![Quantum Cats Sandbox in QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/raw/master/quantum_cats_sandbox.png)

![Final Level II escape room in Japanese](https://github.com/JavaFXpert/QiskitBlocks/raw/master/a_or_b_and_c_ja.png)

## Creating escape rooms in QiskitBlocks
If you'd like to teach a quantum computing concept in the QiskitBlocks game, here are some instructions for [creating escape rooms in QiskitBlocks](https://github.com/JavaFXpert/QiskitBlocks/blob/master/collaborating/creating_escape_rooms.md).
