# User Flows & Low-Fidelity Wireframing (UX)

### 1. The Global Action (Quick Capture)

This is the omnipresent entry point. It requires zero friction and relies on smart system parsing.

- **Trigger:** A global keyboard shortcut on macOS or a persistent `+` action on iOS.
- **UI:** A floating, minimalist input field with a blurred background.
- **Smart Parsing:** The app automatically approximates the input type. Pasting a URL assigns a "Link" icon; dropping a PDF assigns a "Document" icon; typing plain text creates a raw "Note."
- **Routing:** If the user hits enter, it routes directly to the Inbox. If they use a quick dropdown (like a native combobox), they can route it directly to a specific Project or Domain.

### 2. The Navigation Shell (macOS Sidebar & iOS Tabs)

To prevent the sidebar from turning into a cluttered nightmare, we use strict, top-level groupings. We do not expose every single Node in the sidebar; we only expose the macro containers.

- **Dashboard:** The default landing page.
- **Inbox:** The unassigned dump for quick captures.
- **The Atlas (Domains):** An expandable list of the macro fields.
- **Projects:** A list of active, standalone workspaces.
- **The Library:** The global, top-level content vault.

### 3. The Universal Dashboard (The Anchor)

This is the critical addition for mobile usability and quick orientation. When you open the app, you don't want to dig through menus to figure out what to do next.

- **Top Section (Active State):** A horizontal, scrollable stack of Nodes currently marked as "Active." This is your immediate "resume work" zone.
- **Middle Section (Pinned Projects):** Quick-access cards for the specific Projects you are currently researching or building.
- **Bottom Section (Domain Overview):** High-level visual cards showing your Domains and their macro-progress rings.

### 4. The Domain View (Nesting & Versatility)

This is where your "trickle-up" logic shines. When a user clicks a Domain from the sidebar, they enter a highly comprehensive, yet clean, dashboard specific to that field.

- **The Blueprint Entry:** A persistent button or visual toggle at the top to view the nested roadmap for this specific Domain.
- **The Local Library:** A dedicated tab or section strictly containing the content, PDFs, and links nested *anywhere* inside this Domain (trickling up from Tracks, Modules, and Nodes).
- **The Versatile Structure:** The main view displays Tracks (which hold their own Modules and Nodes) alongside standalone Modules that live directly in the Domain, exactly as you requested.

### 5. The State Management (Minimalist Execution)

We strictly avoid over-complicating this. We are not building a Jira board.

- **UI Implementation:** A simple, native toggle on every Node and Project.
- **The Flow:** Toggling a Node to "Active" pulls it to the Universal Dashboard. Toggling it to "Mastered" archives it from the active views and readies it for future review, keeping the interface pristine.

### 6. The Global Library

While local libraries exist inside Domains and Tracks, the Global Library is the master database.

- **The Layout:** A clean, multi-column grid or list view.
- **The Filters:** Native segmented controls at the top allowing the user to instantly filter by Domain, Project, or Content Type (PDF, Video, Link).

### 7. The Blueprint View

This remains a focused, high-value tool rather than a cluttered canvas.

- **The Layout:** A clean, vertical stack view or linear roadmap overlay.
- **The Function:** It visually represents the nesting (Domain -> Track -> Module -> Node) in an intuitive, step-by-step format, allowing the user to see the exact learning path without getting lost in folder hierarchies.