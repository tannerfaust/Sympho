# MVP Scoping

### Sympho Core Data Architecture: The Altas Module

This hierarchy is designed to mirror the intuitive structure of classic education, providing infinite scalability for complex subjects while keeping the UI slick, clean, and minimalist.

**1. The Domain (The Macro Level / The Major)**

- **Definition:** The overarching umbrella for a massive field of study.
- **UI Implementation:** Represented as high-level visual cards on the main Library screen. Each Domain has its own isolated dashboard, color scheme, and macro-progress bar.
- **Example:** Robotics & Artificial Intelligence

**2. The Track (The Mid-Level / The Course)**

- **Definition:** A specific career lane or specialization within a Domain.
- **UI Implementation:** A list of dedicated paths inside the Domain dashboard.
- **Example:** Core Programming Logic

**3. The Module (The Grouping / The Syllabus Section)**

- **Definition:** The major pillars or phases that organize a Track into digestible chunks.
- **UI Implementation:** Collapsible accordion sections within a Track, grouping the atomic building blocks together.
- **Example:** Memory Management & Low-Level Operations

**4. The Node (The Atomic Block / The Lecture)**

- **Definition:** The absolute smallest, testable unit of knowledge. The terminal layer where navigation stops and execution begins.
- **UI Implementation:** The functional container holding all attached resources (PDFs, specific documentation URLs, GitHub links) and the exact spot where the Blueprint generator deconstructs complex topics into a linear path.
- **Example:** Memory allocation and pointers in C.

### The Global Action: Quick Capture for Nodes and Files.

To protect the user's flow state and accommodate unstructured learning, the system supports isolated, unlinked data blocks.

- **The Action:** A global shortcut or omnipresent "+" button that allows immediate entry of raw text, links, or files without categorization.
- **The Orphan Node:** By default, Quick Capture creates a "Node" that is not attached to any Domain or Track. It drops directly into the **Inbox**.
- **The UX Benefit:** Users can execute random, one-off weekend projects (e.g., figuring out a specific ComfyUI workflow) using an Orphan Node without cluttering their main Library. If an Orphan Node becomes highly relevant later, it can be dragged and dropped into an existing Track.

### The Project (The Horizontal Container)

This is the piece we were missing. A Project is a goal-oriented, flexible container.

- **What it is:** A temporary or ongoing workspace designed for a specific output, like researching a YouTube video or building a product.
- **Flexibility:** It can be completely standalone, or it can be nested inside a Domain or Track.
- **In Practice:** If you are developing an iOS and macOS application named CueIn, that doesn't fit neatly into a static "Computer Science" track. It’s a living product. You create a "CueIn App" Project. Inside it, you gather the specific content, PDFs, and Nodes you need to figure out to launch it. If you are implementing an automated notification system for a CRM using Cloudflare Workers, you just spin up a standalone Project, learn what you need, build it, and close it out.

### State Management (Progress Tracking)

To minimize ramp-up friction and power the "Context Switching" JTBD, every Node in the system must possess a strict status tag to dictate where it appears in the UI.

- **Backlog:** Captured, but not actively being studied.
- **Active:** Currently in progress. (Nodes in this state are automatically surfaced to the Command Center dashboard so the user can instantly resume work).
- **Mastered:** Completed. (Nodes in this state trigger the retention/spaced-repetition logic for future review).

### The Blueprints (The tool)/Learning jorney

A tools that helpt you make a see a coherent and convenient learning plan. Can live inside the Node, have differnet forms for different scopes like THe treacks and so on. It should be a highly valuable asset. Sort of a Roadmap of some kind. For Domains it contains or a lot of different featrues to see every tracks inside, in a ver user-frandly way. You can acces and add stuff right in that blueprint/roadmap. It should has different forms like lists format, roadmaps visialisation and so on, sort of like different views

### The Inbox (The Unsorted Zone)

- **What it is:** The default landing zone for everything you capture on the fly via the global shortcut.
- **Function:** It is literally a folder for unassigned content, raw URLs, and Orphan Nodes. You dump things here so your flow isn't broken, and you process them later into Tracks or Projects.

### The Library (The Content Repository)

This is exactly what you were asking for.

- **What it is:** The global, centralized database of every single physical or digital asset you have ever captured.
- **What lives here:** PDFs, YouTube links, course URLs, Notion templates, e-books, and article bookmarks.
- **How it works:** When you use the Quick Capture shortcut to save a PDF, the file itself physically lives in The Library. You can then *link* that PDF to a specific Node in The Atlas, or attach it to a specific Project. If you delete a Project, the PDF doesn't disappear; it stays safely in your Library. Each and every domain has its own folders but Libray also should bea full blows separate module on it;s own, if i may.

###