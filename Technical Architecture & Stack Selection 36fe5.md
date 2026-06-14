# Technical Architecture & Stack Selection

# Technical Architecture & Stack Overview

**Core Objective:** Build a highly efficient, modular, and logically understandable architecture. The system must support complex data nesting while remaining exceptionally fast, ensuring zero latency during data entry to protect the user's flow state.

### Technology Stack Requirements

- **Frontend Ecosystem:** Native multiplatform application for macOS and iOS built strictly with **SwiftUI**.
- **Backend & BaaS:** **Supabase** (serving as the primary source of truth, handling Auth, and utilizing Edge Functions where necessary).
- **Database:** Relational **PostgreSQL** (via Supabase).
- **Asset Storage:** **Supabase Storage** (for housing PDFs, images, and attachments).
- **Local State Management:** **SwiftData** (or a lightweight SQLite wrapper) to provide an offline-first experience, ensuring immediate reads/writes with background syncing to Supabase.

### Required Engineering Deliverables

Based on this overview, the engineering team is required to draft and approve the following before UI implementation begins:

1. **Supabase PostgreSQL Schema:** Exact SQL table definitions, foreign keys, and indexing strategies. This must include the logic for handling the "trickle-up" queries efficiently (e.g., recursive CTEs in Postgres).
2. **SwiftUI Data Models:** The Swift structs/classes mirroring the database schema, including the specific logic for handling the SwiftData to Supabase synchronization.